import SwiftUI
import Combine

class ProjectManager: ObservableObject {
    @Published var htmlContent: String = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                background-color: #f5f5f7;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
            }
            .card {
                background: white;
                padding: 40px;
                border-radius: 20px;
                box-shadow: 0 10px 30px rgba(0,0,0,0.1);
                text-align: center;
                max-width: 400px;
            }
            h1 {
                color: #1d1d1f;
                font-size: 24px;
                margin-bottom: 10px;
            }
            p {
                color: #86868b;
                line-height: 1.5;
            }
            .button {
                background-color: #0071e3;
                color: white;
                border: none;
                padding: 12px 24px;
                border-radius: 999px;
                font-size: 16px;
                cursor: pointer;
                margin-top: 20px;
                transition: background-color 0.2s;
            }
            .button:hover {
                background-color: #0077ed;
            }
        </style>
    </head>
    <body>
        <div class="card">
            <h1>Welcome to Apex</h1>
            <p>This is a live preview of your project. Use the AI tools around you to modify this design instantly.</p>
            <button class="button">Get Started</button>
        </div>
    </body>
    </html>
    """
    
    func updateHTML(_ newHTML: String) {
        self.htmlContent = newHTML
    }
}
