protocol ErrorLogger: Sendable {
   func postSdkError(
       _ message: String,
       error: Error,
       file: String,
       function: String,
       line: Int
   )
   func postApiError(
       errorCode: Int?,
       errorLocation: String?,
       errorMessage: String?,
       errorBody: String?
   )
}

extension ErrorLogger {
    func sdkError(_ message: String, error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        postSdkError(message, error: error, file: file, function: function, line: line)
    }
    func apiError(errorCode: Int? = nil, errorLocation: String? = nil, errorMessage: String? = nil, errorBody: String? = nil) {
        postApiError(errorCode: errorCode, errorLocation: errorLocation, errorMessage: errorMessage, errorBody: errorBody)
    }
}
