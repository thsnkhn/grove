import CryptoKit
import Foundation

// Verify with the shipped public key, not just the release machine's key.
let arguments = CommandLine.arguments
guard arguments.count == 4,
      let signature = Data(base64Encoded: arguments[2]),
      let publicKey = Data(base64Encoded: arguments[3]) else {
    fatalError("Usage: verify_update.swift archive signature public-key")
}
let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
let archive = try Data(contentsOf: URL(fileURLWithPath: arguments[1]), options: .mappedIfSafe)
guard key.isValidSignature(signature, for: archive) else {
    fatalError("Update signature does not match Grove's public key.")
}
print("Update signature verified.")
