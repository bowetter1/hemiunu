import Foundation

/// High-level design workflow wrapper
final class DesignService {
    let client: APIClient

    init(client: APIClient = APIClient.shared) {
        self.client = client
    }
}
