import Foundation
import ServerKit
public enum VaultCommunicationError: Error {
  case connectionError(Error)
  case timedOut
  case parseError
  case notAuthorized
  case tokenNotSet
}
public final class VaultClient {
  let vaultAuthority: URL
  let session = URLSession(configuration: .default)
  public var token: String? = nil
  public init(vaultAuthority: URL = URL(string: "http://localhost:8200")!) {
    self.vaultAuthority = vaultAuthority
  }

  public func status() throws -> (sealed: Bool, healthy: Bool) {
    let dict = try Sys.health(vaultAuthority: vaultAuthority)
    let sealed = dict["sealed"] as! Bool
    return (sealed, true)
  }
}

/// Inspecting the currently set token
extension VaultClient {
  public func checkToken() throws {
    _ = try lookupSelfTokenData()
  }

  public func tokenTTL() throws -> Int {
    let data = try lookupSelfTokenData()
    guard let ttl = data["ttl"] as? Int else {
      throw VaultCommunicationError.parseError
    }
    return ttl
  }

  private func lookupSelfTokenData() throws -> [String:Any] {
    let d = try Auth.Token.lookupSelf(vaultAuthority: vaultAuthority, token: getToken())
    guard let data = d["data"] as? [String:Any] else {
      throw VaultCommunicationError.parseError
    }
    return data
  }

  public func listPolicies() throws -> [String] {
    let data = try lookupSelfTokenData()
    guard let policies = data["policies"] as? [String] else {
      throw VaultCommunicationError.parseError
    }
    return policies
  }

  public func renewToken() throws {
    try Auth.Token.renewSelf(vaultAuthority: vaultAuthority, token: getToken())
  }
}

/// Interface to Generic
extension VaultClient {
  public func store(_ secret: [String:String], atPath path: String) throws {
    try Secret.Generic.store(vaultAuthority: vaultAuthority, token: getToken(), secret: secret, path: path)
  }

  public func secret(atPath path: String) throws -> [String:String] {
    let dict = try Secret.Generic.read(vaultAuthority: vaultAuthority, token: getToken(), path: path)
    guard let data = dict["data"] as? [String:String] else {
      throw VaultCommunicationError.parseError
    }
    return data
  }
}

private extension VaultClient {
  func getToken() throws -> String {
    guard let t = token else { throw VaultCommunicationError.tokenNotSet }
    return t
  }
}
