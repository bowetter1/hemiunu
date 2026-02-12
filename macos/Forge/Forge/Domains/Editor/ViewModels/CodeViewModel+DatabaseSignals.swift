import Foundation

extension CodeViewModel {
    func detectDatabaseSignals(project: String, localFiles: [LocalFileInfo]) -> (engines: [String], migrationCount: Int, schemaCount: Int, risks: [String]) {
        var engines: Set<String> = []
        var migrationCount = 0
        var schemaCount = 0
        var rawSQLFileCount = 0

        let sqlEngines: Set<String> = ["PostgreSQL", "MySQL", "SQLite"]

        for file in localFiles {
            let pathLower = file.path.lowercased()
            let ext = (file.path as NSString).pathExtension.lowercased()

            if pathLower.contains("/migrations/") || pathLower.hasPrefix("migrations/") {
                if ["sql", "py", "ts", "js", "rb"].contains(ext) {
                    migrationCount += 1
                }
            }

            if pathLower.hasSuffix("schema.prisma")
                || pathLower.hasSuffix("schema.sql")
                || pathLower.hasSuffix("db/schema.rb")
                || pathLower.hasSuffix("alembic.ini")
                || pathLower.contains("/alembic/versions/")
                || pathLower.contains("/prisma/migrations/") {
                schemaCount += 1
            }

            if ext == "sql" && !(pathLower.contains("/migrations/") || pathLower.hasPrefix("migrations/")) {
                rawSQLFileCount += 1
            }
        }

        let contentScanCandidates = localFiles.filter { shouldScanForDatabase(path: $0.path) }
        for file in contentScanCandidates {
            guard let content = try? workspace.readFile(project: project, path: file.path) else { continue }
            mergeDatabaseSignals(content: content.lowercased(), into: &engines)
        }

        var risks: [String] = []
        let sqlEngineCount = engines.intersection(sqlEngines).count
        if engines.isEmpty && (migrationCount > 0 || schemaCount > 0) {
            risks.append("Schema/migrations detected but DB engine is unclear.")
        }
        if !engines.isEmpty && migrationCount == 0 {
            risks.append("DB detected but no migrations folder was found.")
        }
        if sqlEngineCount > 1 {
            risks.append("Multiple SQL engines detected; verify this is intentional.")
        }
        if rawSQLFileCount >= 20 {
            risks.append("Many raw SQL files outside migrations (\(rawSQLFileCount)).")
        }

        return (
            engines: engines.sorted(),
            migrationCount: migrationCount,
            schemaCount: schemaCount,
            risks: risks
        )
    }

    private func shouldScanForDatabase(path: String) -> Bool {
        let pathLower = path.lowercased()
        let fileName = (pathLower as NSString).lastPathComponent
        let trackedNames: Set<String> = [
            "package.json", "requirements.txt", "pyproject.toml", "pipfile", "pipfile.lock",
            "poetry.lock", "docker-compose.yml", "docker-compose.yaml", ".env", ".env.example",
            ".env.local", "schema.prisma", "alembic.ini"
        ]

        if trackedNames.contains(fileName) { return true }
        if pathLower.contains("database") && (fileName.hasSuffix(".yml") || fileName.hasSuffix(".yaml") || fileName.hasSuffix(".json")) { return true }
        if pathLower.contains("prisma") || pathLower.contains("alembic") || pathLower.contains("typeorm") || pathLower.contains("sequelize") || pathLower.contains("drizzle") {
            return true
        }
        return false
    }

    private func mergeDatabaseSignals(content: String, into engines: inout Set<String>) {
        let markers: [(String, [String])] = [
            ("PostgreSQL", ["postgres://", "postgresql://", "\"pg\"", "psycopg", "asyncpg"]),
            ("MySQL", ["mysql://", "\"mysql2\"", "pymysql", "mysqlclient", "aiomysql"]),
            ("SQLite", ["sqlite://", "sqlite3", "better-sqlite3"]),
            ("MongoDB", ["mongodb://", "mongodb+srv://", "mongoose", "pymongo", "motor"]),
            ("Redis", ["redis://", "ioredis", "\"redis\"", "redis-py"])
        ]

        for (engine, hints) in markers where hints.contains(where: { content.contains($0) }) {
            engines.insert(engine)
        }
    }
}
