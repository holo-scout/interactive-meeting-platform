const { onRequest, onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");

admin.initializeApp();

// Initialize Gemini with your API Key
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "YOUR_FALLBACK_KEY");

/**
 * 1. Extract Topics from a PDF
 */
exports.extractTopicsFromPdf = onCall(async (request) => {
  const { fileUrl } = request.data;
  console.log("[extractTopicsFromPdf] Started. fileUrl:", fileUrl);
  
  if (!fileUrl) {
    console.error("[extractTopicsFromPdf] Error: Missing PDF fileUrl parameter.");
    throw new Error("Missing PDF fileUrl parameter.");
  }

  try {
    // Fetch the PDF file as bytes
    console.log("[extractTopicsFromPdf] Fetching PDF file from URL...");
    const response = await fetch(fileUrl);
    if (!response.ok) {
      throw new Error(`Failed to fetch PDF. Status: ${response.status}`);
    }
    const pdfBuffer = await response.arrayBuffer();
    console.log(`[extractTopicsFromPdf] PDF fetched successfully. Size: ${pdfBuffer.byteLength} bytes`);

    const model = genAI.getGenerativeModel({ model: "gemini-3.5-flash" });

    const prompt = "Analyze this PDF document and list the top 5 distinct study/meeting topics covered in it.";

    console.log("[extractTopicsFromPdf] Calling Gemini API...");
    const result = await model.generateContent([
      {
        inlineData: {
          data: Buffer.from(pdfBuffer).toString("base64"),
          mimeType: "application/pdf"
        }
      },
      prompt
    ]);

    // Request structural output format or clean it up
    const text = result.response.text();
    console.log("[extractTopicsFromPdf] Raw response from Gemini:", text);
    
    // Parse lines or use Gemini structured output schema
    const topics = text.split("\n")
      .map(line => line.replace(/^[\d\-\*\s\.]+/g, "").trim())
      .filter(line => line.length > 0)
      .slice(0, 5);

    console.log("[extractTopicsFromPdf] Parsed topics:", topics);
    return { topics };
  } catch (error) {
    console.error("[extractTopicsFromPdf] Exception occurred:", error);
    throw error;
  }
});

/**
 * 2. Generate Structured Quiz Questions matching Flutter Model
 */
exports.generateQuizQuestions = onCall(async (request) => {
  console.log("[generateQuizQuestions] Started. Request data:", JSON.stringify(request.data));
  const { fileUrl, selectedTopics, mcqCount, checkboxCount, openCount, sessionId, relevantToQna } = request.data;

  try {
    // 1. Fetch Q&A Questions if toggled active
    let studentQuestionsText = "";
    if (relevantToQna && sessionId) {
      console.log(`[generateQuizQuestions] Fetching Q&As for sessionId: ${sessionId}...`);
      try {
        const questionsSnapshot = await admin.firestore()
          .collection('sessions')
          .doc(sessionId)
          .collection('questions')
          .limit(20)
          .get();

        const questionsList = [];
        questionsSnapshot.forEach(doc => {
          const qData = doc.data();
          if (qData && qData.content) {
            questionsList.push(`- ${qData.content}`);
          }
        });

        console.log(`[generateQuizQuestions] Found ${questionsList.length} student questions`);
        if (questionsList.length > 0) {
          studentQuestionsText = questionsList.join("\n");
        }
      } catch (error) {
        console.error("[generateQuizQuestions] Failed to fetch session Q&As:", error);
      }
    } else {
      console.log("[generateQuizQuestions] Skipping Q&A fetch. relevantToQna:", relevantToQna, "sessionId:", sessionId);
    }

    console.log("[generateQuizQuestions] Fetching PDF file from URL...");
    const response = await fetch(fileUrl);
    if (!response.ok) {
      throw new Error(`Failed to fetch PDF. Status: ${response.status}`);
    }
    const pdfBuffer = await response.arrayBuffer();
    console.log(`[generateQuizQuestions] PDF fetched successfully. Size: ${pdfBuffer.byteLength} bytes`);

    const model = genAI.getGenerativeModel({ 
      model: "gemini-3.5-flash",
      // Force structured JSON output matching our exact schema
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: {
          type: "object",
          properties: {
            questions: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  questionText: { type: "string" },
                  type: { type: "string", enum: ["multiple_choice", "checkbox", "open_ended"] },
                  options: { type: "array", items: { type: "string" } },
                  correctAnswers: { type: "array", items: { type: "string" } }
                },
                required: ["questionText", "type", "options", "correctAnswers"]
              }
            }
          },
          required: ["questions"]
        }
      }
    });

    const prompt = `
      Based on the attached PDF document, generate a set of educational quiz questions targeting these specific topics: ${selectedTopics.join(", ")}.
      
      You must generate exactly:
      - ${mcqCount} multiple_choice questions (single correct answer in correctAnswers)
      - ${checkboxCount} checkbox questions (multiple correct answers in correctAnswers)
      - ${openCount} open_ended questions (options and correctAnswers should be empty arrays)
      
      CRITICAL RULES:
      1. Prioritize generating questions that are strictly related to the content in the PDF. Under all circumstances, the content in the PDF is the absolute source of truth. If any student Q&A topic is irrelevant to the PDF content, ignore it and prioritize the PDF content.
      2. ${relevantToQna && studentQuestionsText ? `
         The following are recent student questions from this session's Q&A board:
         ${studentQuestionsText}
         
         If these student questions are relevant to the PDF content, make SOME (but not all) of the generated questions relevant to these student queries.
         NOTE: Not every generated quiz question has to be relevant to these student Q&As. For example, if there is only 1 student question, but you are generating 3 or more quiz questions, only 1 of the generated questions should address that student's query, while the remaining questions should be based on other topics inside the PDF.
         ` : 'Do not consider Q&As; base questions strictly on the PDF.'}
         
      Return the output matching the requested JSON schema.
    `;

    console.log("[generateQuizQuestions] Calling Gemini API...");
    const result = await model.generateContent([
      {
        inlineData: {
          data: Buffer.from(pdfBuffer).toString("base64"),
          mimeType: "application/pdf"
        }
      },
      prompt
    ]);

    const rawText = result.response.text();
    console.log("[generateQuizQuestions] Raw response from Gemini:", rawText);

    const quizData = JSON.parse(rawText);
    console.log(`[generateQuizQuestions] Successfully generated ${(quizData.questions || []).length} questions.`);
    return quizData;
  } catch (error) {
    console.error("[generateQuizQuestions] Exception occurred:", error);
    throw error;
  }
});