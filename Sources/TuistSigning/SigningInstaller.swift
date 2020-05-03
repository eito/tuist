import TSCBasic
import Foundation
import TuistSupport

enum SigningInstallerError: FatalError, Equatable {
    case noFileExtension(AbsolutePath)
    case provisioningProfilePathNotFound(ProvisioningProfile)
    case revokedCertificate(Certificate)
    case expiredProvisioningProfile(ProvisioningProfile)

    var type: ErrorType {
        switch self {
        case .noFileExtension, .provisioningProfilePathNotFound, .revokedCertificate, .expiredProvisioningProfile:
            return .abort
        }
    }

    var description: String {
        switch self {
        case let .noFileExtension(path):
            return "Unable to parse extension from file at \(path.pathString)"
        case let .revokedCertificate(certificate):
            return "The certificate has been revoked \(certificate.name)"
        case let .expiredProvisioningProfile(provisioningProfile):
            return "The provisioning profile \(provisioningProfile.name) has expired"
        case let .provisioningProfilePathNotFound(provisioningProfile):
            return "Could not find any path for \(provisioningProfile.name)"
        }
    }
}

protocol SigningInstalling {
    func installProvisioningProfile(_ provisioningProfile: ProvisioningProfile) throws
    func installCertificate(_ certificate: Certificate, keychainPath: AbsolutePath) throws
}

final class SigningInstaller: SigningInstalling {
    private let securityController: SecurityControlling

    init(securityController: SecurityControlling = SecurityController()) {
        self.securityController = securityController
    }

    func installProvisioningProfile(_ provisioningProfile: ProvisioningProfile) throws {
        guard provisioningProfile.expirationDate > Date() else { throw SigningInstallerError.expiredProvisioningProfile(provisioningProfile) }
        let provisioningProfilesPath = FileHandler.shared.homeDirectory.appending(RelativePath("Library/MobileDevice/Provisioning Profiles"))
        if !FileHandler.shared.exists(provisioningProfilesPath) {
            try FileHandler.shared.createFolder(provisioningProfilesPath)
        }
        guard
            let provisioningProfileSourcePath = provisioningProfile.path
            else { throw SigningInstallerError.provisioningProfilePathNotFound(provisioningProfile) }
        guard
            let profileExtension = provisioningProfileSourcePath.extension
            else { throw SigningInstallerError.noFileExtension(provisioningProfileSourcePath) }
        
        let provisioningProfilePath = provisioningProfilesPath.appending(component: provisioningProfile.uuid + "." + profileExtension)
        if FileHandler.shared.exists(provisioningProfilePath) {
            try FileHandler.shared.delete(provisioningProfilePath)
        }
        try FileHandler.shared.copy(from: provisioningProfileSourcePath,
                                    to: provisioningProfilePath)

        logger.notice("Installed provisioning profile \(provisioningProfileSourcePath.pathString) to \(provisioningProfilePath.pathString)")
    }

    func installCertificate(_ certificate: Certificate, keychainPath: AbsolutePath) throws {
        try securityController.importCertificate(certificate, keychainPath: keychainPath)
        logger.notice("Installed certificate with public key at \(certificate.publicKey.pathString) and private key \(certificate.privateKey.pathString) at to keychain at \(keychainPath.pathString)")
    }
}
