enum LogLevel:String {
    case info, warning, error
    
    var title: String {
        String(describing: self).uppercased()
    }
}
