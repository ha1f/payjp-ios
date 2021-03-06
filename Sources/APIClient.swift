//
//  PAY.JP APIClient.swift
//  https://pay.jp/docs/api/
//

import Foundation
import PassKit

@objc(PAYAPIClient) public class APIClient: NSObject {
    private let publicKey: String
    private let baseURL: String = "https://api.pay.jp/v1"
    
    private lazy var authCredential: String = {
        let credentialData = "\(self.publicKey):".data(using: .utf8)!
        let base64Credential = credentialData.base64EncodedString()
        return "Basic \(base64Credential)"
    }()

    public init(publicKey: String) {
        self.publicKey = publicKey
    }
    
    public typealias APIResponse = Result<Token, APIError>
    
    /// Create PAY.JP Token
    /// - parameter token: ApplePay Token
    public func createToken(
        with token: PKPaymentToken,
        completionHandler: @escaping (APIResponse) -> ())
    {
        guard let url = URL(string: "\(baseURL)/tokens") else { return }
        guard let body = String(data: token.paymentData, encoding: String.Encoding.utf8)?
            .addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics) else {
                completionHandler(.failure(.invalidApplePayToken(token)))
                return
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = "card=\(body)".data(using: .utf8)
        req.setValue(authCredential, forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: req, completionHandler: { (data, res, err) in
            if let e = err {
                completionHandler(.failure(.errorResponse(e)))
                return
            }
            
            guard let response = res as? HTTPURLResponse else {
                completionHandler(.failure(.invalidResponse(nil)))
                return
            }
            
            guard let data = data else {
                completionHandler(.failure(.invalidResponse(response)))
                return
            }
            
            var json: Any
            do {
                json = try JSONSerialization.jsonObject(with: data, options:.mutableContainers)
            }catch {
                completionHandler(.failure(.invalidResponseBody(data)))
                return
            }
            
            if response.statusCode != 200 {
                completionHandler(.failure(.errorJSON(json)))
                return
            }
            
            do {
                let token = try Token.decodeValue(json)
                completionHandler(.success(token))
            } catch {
                completionHandler(.failure(.invalidJSON(json)))
            }
        })
        
        task.resume()
    }
}

// Objective-C API
extension APIClient {
    public func createTokenWith(
        _ token: PKPaymentToken,
        completionHandler: @escaping (Error?, Token?) -> ()) {
        
        self.createToken(with: token) { (response) in
            switch response {
            case .success(let token):
                completionHandler(nil, token)
            case .failure(let error):
                completionHandler(error, nil)
            }
        }
    }
}
