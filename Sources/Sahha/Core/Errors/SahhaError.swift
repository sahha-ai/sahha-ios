enum SahhaError: Error {
    case message(String)
    
    var message: String {
        switch self {
        case .message(let msg):
            return msg
        }
    }
    
    var localizedDescription: String {
        return message
    }
}
