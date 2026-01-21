import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let appleUserId: String?
    let email: String
    let fullName: String?
    let userType: UserType?
    let teacherId: Int?
    let createdAt: Date
}

enum UserType: String, Codable {
    case teacher
    case student
    case both
}
