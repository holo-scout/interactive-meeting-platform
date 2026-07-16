class Folder {
  final String folderID;
  final String name;
  final String userID;

  Folder({required this.folderID, required this.name, required this.userID});

  Map<String, dynamic> toMap() {
    return {'folderID': folderID, 'name': name, 'userID': userID};
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      folderID: map['folderID'] ?? '',
      name: map['name'] ?? '',
      userID: map['userID'] ?? '',
    );
  }
}
