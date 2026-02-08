import Foundation
import Compression

final class APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let interceptorStore: APIInterceptorStoreProtocol?

    init(baseURL: URL, session: URLSession = .shared, interceptorStore: APIInterceptorStoreProtocol? = nil) {
        self.baseURL = baseURL
        self.session = session
        self.interceptorStore = interceptorStore
    }

    func send(_ request: APIRequest) async throws {
        _ = try await executePipeline(request: request)
    }

    func send<T: Decodable>(_ request: APIRequest) async throws -> T {
        let (data, response) = try await executePipeline(request: request)

        if response.statusCode == 204 || data.isEmpty {
            throw APIErrorResponse(
                title: "No Content",
                statusCode: 204,
                location: "APIClient.send",
                errors: [.init(origin: "Decoding", errors: ["No content for type \(T.self)"])]
            )
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIErrorResponse(
                title: "Decoding Error",
                statusCode: response.statusCode,
                location: "APIClient.send",
                errors: [.init(origin: "Decoding", errors: [error.localizedDescription])]
            )
        }
    }

    private func executePipeline(request: APIRequest) async throws -> APIResponse {
        let interceptors = await interceptorStore?.getInterceptors() ?? []
        let next = buildNext(from: interceptors)
        return try await next(request)
    }

    private func buildNext(from chain: [any APIInterceptorProtocol]) -> NextAPIRequest {
        var current: NextAPIRequest = { try await self.performRequest($0) }

        for interceptor in chain {
            let next = current
            current = { request in
                try await interceptor.intercept(request: request, next: next)
            }
        }
        return current
    }

    private func buildURLRequest(from request: APIRequest) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(request.endpoint), resolvingAgainstBaseURL: true) else {
            throw APIErrorResponse(
                title: "Invalid URL",
                statusCode: -1,
                location: "APIClient.buildURLRequest",
                errors: [.init(origin: "URL", errors: ["Invalid endpoint: \(request.endpoint)"])]
            )
        }
        components.queryItems = request.queryParameters

        guard let url = components.url else {
            throw APIErrorResponse(
                title: "Invalid URL",
                statusCode: -1,
                location: "APIClient.buildURLRequest",
                errors: [.init(origin: "URL", errors: ["Invalid endpoint: \(request.endpoint)"])]
            )
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body

        var headers: [String: String] = ["Content-Type": "application/json"]
        headers.merge(request.headers ?? [:]) { $1 }
        urlRequest.allHTTPHeaderFields = headers

        return urlRequest
    }

    private func performRequest(_ request: APIRequest) async throws -> APIResponse {
        var urlRequest: URLRequest
        do {
            urlRequest = try buildURLRequest(from: request)
            // Compress the body if it's > 1kb
            if let compressedRequest = try compressBodyIfNeeded(urlRequest) {
                Sahha.log("[Sahha Compression] Compressed request body: \(urlRequest.httpBody?.count ?? 0) bytes → \(compressedRequest.httpBody?.count ?? 0) bytes")
                urlRequest = compressedRequest
            }
        } catch let apiError as APIErrorResponse {
            throw apiError
        } catch {
            throw APIErrorResponse(
                title: "Request Building Error",
                statusCode: -1,
                location: "APIClient.performRequest",
                errors: [.init(origin: "Request Building", errors: [error.localizedDescription])]
            )
        }

        let data: Data
        let response: URLResponse
        do {
            Sahha.log("[Sahha Network] \(urlRequest.httpMethod ?? "GET") \(urlRequest.url?.absoluteString ?? "") | Headers: \(urlRequest.allHTTPHeaderFields ?? [:])")
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIErrorResponse(
                title: "Request Failed",
                statusCode: -1,
                location: "APIClient.performRequest",
                errors: [.init(origin: "Network", errors: [error.localizedDescription])]
            )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIErrorResponse(
                title: "Invalid Response",
                statusCode: -1,
                location: "APIClient.performRequest",
                errors: [.init(origin: "Network", errors: ["No HTTPURLResponse"])]
            )
        }

        switch httpResponse.statusCode {
        case 200...299:
            return APIResponse(data, httpResponse)
        default:
            Sahha.log("[Sahha Error] HTTP \(httpResponse.statusCode) | Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            do {
                let apiError = try JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw apiError
            } catch {
                throw APIErrorResponse(
                    title: "HTTP Error",
                    statusCode: httpResponse.statusCode,
                    location: "APIClient.performRequest",
                    errors: [.init(origin: "HTTP", errors: ["HTTP error with status code \(httpResponse.statusCode)"])]
                )
            }
        }
    }

    //// Method to compress large bodies with gzip
    private func compressBodyIfNeeded(_ urlRequest: URLRequest) throws -> URLRequest? {
        guard let body = urlRequest.httpBody, body.count > 1024 else {
            return nil // shows no comp. for bodies < 1kb
        }
        
        var mutableRequest = urlRequest
        do {
            // Compression logic here
            let compressedData = try compressGzip(data: body)
            mutableRequest.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
            mutableRequest.httpBody = compressedData
            return mutableRequest
        } catch {
            // Fallback: Log and return original request if compression fails
            return nil
        }
    }

    //function to compress data with gzip using Foundation's Compression, no added library needed
    private func compressGzip(data: Data) throws -> Data {
        guard !data.isEmpty else { return data }
        
        // First, compress using deflate (ZLIB without header/footer)
        let destinationBufferSize = data.count
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationBufferSize)
        defer { destinationBuffer.deallocate() }
        
        let compressedSize = data.withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) -> Int in
            guard let sourcePtr = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            return compression_encode_buffer(
                destinationBuffer,
                destinationBufferSize,
                sourcePtr,
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        
        guard compressedSize > 0 else {
            throw SahhaError(message: "Deflate compression failed")
        }
        
        let deflateData = Data(bytes: destinationBuffer, count: compressedSize)
        
        // Now add gzip header and footer
        var gzipData = Data()
        
        // GZIP Header (10 bytes)
        gzipData.append(0x1F) // ID1
        gzipData.append(0x8B) // ID2
        gzipData.append(0x08) // CM (deflate)
        gzipData.append(0x00) // FLG (no flags)
        gzipData.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // MTIME (0)
        gzipData.append(0x00) // XFL
        gzipData.append(0xFF) // OS (unknown)
        
        // Append deflate data
        gzipData.append(deflateData)
        
        // GZIP Footer (8 bytes): CRC32 and ISIZE
        let crc32 = crc32checksum(data: data)
        let isize = UInt32(data.count % (1 << 32))
        
        // Append CRC32 (little-endian)
        gzipData.append(UInt8(crc32 & 0xFF))
        gzipData.append(UInt8((crc32 >> 8) & 0xFF))
        gzipData.append(UInt8((crc32 >> 16) & 0xFF))
        gzipData.append(UInt8((crc32 >> 24) & 0xFF))
        
        // Append ISIZE (little-endian)
        gzipData.append(UInt8(isize & 0xFF))
        gzipData.append(UInt8((isize >> 8) & 0xFF))
        gzipData.append(UInt8((isize >> 16) & 0xFF))
        gzipData.append(UInt8((isize >> 24) & 0xFF))
        
        return gzipData
    }

    // Helper function for CRC32
    private func crc32checksum(data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        
        let polynomial: UInt32 = 0xEDB88320
        
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                let mask: UInt32 = (crc & 1) == 0 ? 0 : UInt32.max
                crc = (crc >> 1) ^ (polynomial & mask)
            }
        }
        
        return crc ^ 0xFFFFFFFF
    }
}
