enum LogLevel:String {
    case info
    case warning
    case error
    
    var title: String {
        String(describing: self).uppercased()
    }
}
