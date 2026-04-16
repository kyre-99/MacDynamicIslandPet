import Foundation

// MARK: - News Item Structure

/// 新闻条目结构体
///
/// 存储从RSS源获取的单条新闻信息
/// US-010: 自主思考系统设计与实现
struct NewsItem: Codable, Identifiable {
    /// 唯一标识（使用URL或标题hash）
    var id: String

    /// 新闻标题
    var title: String

    /// 新闻摘要/描述
    var summary: String

    /// 新闻链接
    var link: String?

    /// 发布时间（可选）
    var pubDate: Date?

    /// 新闻来源
    var source: String?

    /// 创建新闻条目
    static func create(
        title: String,
        summary: String,
        link: String? = nil,
        pubDate: Date? = nil,
        source: String? = nil
    ) -> NewsItem {
        return NewsItem(
            id: title.hashDescription,
            title: title,
            summary: summary,
            link: link,
            pubDate: pubDate,
            source: source
        )
    }
}

/// String扩展：生成hash描述作为ID
extension String {
    var hashDescription: String {
        return String(abs(hashValue))
    }
}

// MARK: - News Fetcher Error

/// 新闻获取错误类型
enum NewsFetchError: Error, LocalizedError {
    /// 无效URL
    case invalidURL
    /// 网络错误
    case networkError(String)
    /// 解析错误
    case parseError
    /// 无数据
    case noData
    /// 超时
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid RSS URL"
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .parseError:
            return "Failed to parse RSS feed"
        case .noData:
            return "No news data available"
        case .timeout:
            return "Request timed out"
        }
    }
}

// MARK: - News Fetcher

/// 新闻获取器
///
/// 从RSS源获取新闻数据，支持多种RSS格式解析
/// US-010: 自主思考系统设计与实现
class NewsFetcher {
    /// 共享单例实例
    static let shared = NewsFetcher()

    /// 请求超时时间（秒）
    private let timeout: TimeInterval = 30.0

    /// 每个领域获取的新闻数量上限
    private let maxNewsPerCategory: Int = 5

    /// 缓存新闻数据（避免频繁请求）
    private var newsCache: [NewsCategory: [NewsItem]] = [:]

    /// 缓存过期时间（秒）
    private let cacheExpiration: TimeInterval = 3600  // 1小时

    /// 缓存时间戳
    private var cacheTimestamp: [NewsCategory: Date] = [:]

    private init() {}

    // MARK: - Public Fetch Methods

    /// 获取指定领域的新闻
    /// - Parameters:
    ///   - category: 新闻领域
    ///   - completion: 完成回调
    func fetchNews(for category: NewsCategory, completion: @escaping (Result<[NewsItem], NewsFetchError>) -> Void) {
        // 检查缓存是否有效
        if let cached = newsCache[category],
           let timestamp = cacheTimestamp[category],
           Date().timeIntervalSince(timestamp) < cacheExpiration {
            print("📰 NewsFetcher: Using cached news for \(category.displayName)")
            completion(.success(cached))
            return
        }

        // 获取RSS源URL
        guard let rssURL = category.rssSource else {
            completion(.failure(.invalidURL))
            return
        }

        print("📰 NewsFetcher: Fetching news from \(rssURL.absoluteString)")

        // 发起网络请求
        fetchRSSFeed(url: rssURL) { result in
            switch result {
            case .success(let rssContent):
                // 解析RSS内容
                let newsItems = self.parseRSSContent(rssContent, category: category)

                if newsItems.isEmpty {
                    completion(.failure(.noData))
                } else {
                    // 缓存结果
                    self.newsCache[category] = newsItems
                    self.cacheTimestamp[category] = Date()

                    print("📰 NewsFetcher: Fetched \(newsItems.count) news items for \(category.displayName)")
                    completion(.success(newsItems))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 获取多个领域的新闻（合并）
    /// - Parameters:
    ///   - categories: 新闻领域数组
    ///   - completion: 完成回调
    func fetchMultipleCategories(
        categories: [NewsCategory],
        completion: @escaping (Result<[NewsCategory: [NewsItem]], NewsFetchError>) -> Void
    ) {
        var results: [NewsCategory: [NewsItem]] = [:]
        var errors: [NewsFetchError] = []

        let group = DispatchGroup()

        for category in categories {
            group.enter()

            fetchNews(for: category) { result in
                switch result {
                case .success(let items):
                    results[category] = items
                case .failure(let error):
                    errors.append(error)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if results.isEmpty && !errors.isEmpty {
                completion(.failure(errors.first!))
            } else {
                completion(.success(results))
            }
        }
    }

    // MARK: - RSS Feed Fetching

    /// 发起RSS请求
    /// - Parameters:
    ///   - url: RSS源URL
    ///   - completion: 完成回调
    private func fetchRSSFeed(url: URL, completion: @escaping (Result<String, NewsFetchError>) -> Void) {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = "GET"

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                if (error as NSError).code == NSURLErrorTimedOut {
                    completion(.failure(.timeout))
                } else {
                    completion(.failure(.networkError(error.localizedDescription)))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.networkError("Invalid response")))
                return
            }

            if httpResponse.statusCode >= 400 {
                completion(.failure(.networkError("HTTP error: \(httpResponse.statusCode)")))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            // 将数据转换为字符串
            let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? ""

            if content.isEmpty {
                completion(.failure(.noData))
            } else {
                completion(.success(content))
            }
        }

        task.resume()
    }

    // MARK: - RSS Content Parsing

    /// 解析RSS内容
    /// - Parameters:
    ///   - content: RSS XML内容
    ///   - category: 新闻领域（用于fallback）
    /// - Returns: 解析出的新闻条目数组
    private func parseRSSContent(_ content: String, category: NewsCategory) -> [NewsItem] {
        var items: [NewsItem] = []

        // 尝试解析标准RSS格式
        // RSS格式：<item><title>...</title><description>...</description><link>...</link></item>

        // 使用简单的字符串解析（避免引入XML解析器）
        let itemPattern = "<item>(.*?)</item>"
        let titlePattern = "<title>(.*?)</title>"
        let descriptionPattern = "<description>(.*?)</description>"
        let linkPattern = "<link>(.*?)</link>"

        // 提取所有item块
        let itemMatches = matches(for: itemPattern, in: content)

        for itemContent in itemMatches {
            // 提取标题
            let titleMatch = matches(for: titlePattern, in: itemContent).first ?? ""

            // 清理HTML标签
            let title = cleanHTMLTags(titleMatch).trimmingCharacters(in: .whitespacesAndNewlines)

            // 提取描述/摘要
            let descriptionMatch = matches(for: descriptionPattern, in: itemContent).first ?? ""
            let summary = cleanHTMLTags(descriptionMatch).trimmingCharacters(in: .whitespacesAndNewlines)

            // 提取链接
            let linkMatch = matches(for: linkPattern, in: itemContent).first ?? ""
            let link = cleanHTMLTags(linkMatch).trimmingCharacters(in: .whitespacesAndNewlines)

            // 只添加有标题的新闻
            if !title.isEmpty {
                let newsItem = NewsItem.create(
                    title: title,
                    summary: summary.isEmpty ? "\(category.displayName)新闻" : summary,
                    link: link.isEmpty ? nil : link,
                    source: category.displayName
                )
                items.append(newsItem)
            }
        }

        // 如果标准RSS解析失败，尝试Reddit RSS格式
        if items.isEmpty {
            items = parseRedditRSS(content, category: category)
        }

        // 限制数量
        return Array(items.prefix(maxNewsPerCategory))
    }

    /// 解析Reddit RSS格式
    /// Reddit RSS使用不同的格式，尝试提取entry/content
    /// - Parameters:
    ///   - content: RSS内容
    ///   - category: 新闻领域
    /// - Returns: 解析出的新闻条目数组
    private func parseRedditRSS(_ content: String, category: NewsCategory) -> [NewsItem] {
        var items: [NewsItem] = []

        // Reddit RSS格式：<entry><title>...</title><content>...</content><link href="..."/></entry>
        let entryPattern = "<entry>(.*?)</entry>"
        let titlePattern = "<title>(.*?)</title>"
        let contentPattern = "<content.*?>(.*?)</content>"
        let linkPattern = "<link.*?href=\"(.*?)\".*?/>"

        let entryMatches = matches(for: entryPattern, in: content)

        for entryContent in entryMatches {
            let titleMatch = matches(for: titlePattern, in: entryContent).first ?? ""
            let title = cleanHTMLTags(titleMatch).trimmingCharacters(in: .whitespacesAndNewlines)

            let contentMatch = matches(for: contentPattern, in: entryContent).first ?? ""
            let summary = cleanHTMLTags(contentMatch).trimmingCharacters(in: .whitespacesAndNewlines)

            let linkMatch = matches(for: linkPattern, in: entryContent).first ?? ""
            let link = linkMatch.trimmingCharacters(in: .whitespacesAndNewlines)

            if !title.isEmpty {
                let newsItem = NewsItem.create(
                    title: title,
                    summary: summary.isEmpty ? "Reddit \(category.displayName)" : summary,
                    link: link.isEmpty ? nil : link,
                    source: "Reddit"
                )
                items.append(newsItem)
            }
        }

        return items
    }

    // MARK: - Helper Methods

    /// 使用正则表达式匹配
    /// - Parameters:
    ///   - pattern: 正则表达式模式
    ///   - text: 待匹配文本
    /// - Returns: 匹配结果数组
    private func matches(for pattern: String, in text: String) -> [String] {
        var results: [String] = []

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return results
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)

        for match in matches {
            if let rangeRange = Range(match.range(at: 1), in: text) {
                results.append(String(text[rangeRange]))
            }
        }

        return results
    }

    /// 清理HTML标签
    /// - Parameter html: 包含HTML标签的文本
    /// - Returns: 清理后的纯文本
    private func cleanHTMLTags(_ html: String) -> String {
        // 移除HTML标签
        var text = html

        // 移除CDATA标记
        text = text.replacingOccurrences(of: "<![CDATA[", with: "")
        text = text.replacingOccurrences(of: "]]>", with: "")

        // 移除常见HTML标签
        let htmlTagPattern = "<[^>]+>"
        guard let regex = try? NSRegularExpression(pattern: htmlTagPattern, options: []) else {
            return text
        }

        let range = NSRange(text.startIndex..., in: text)
        text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")

        // 解码HTML实体
        text = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")

        return text
    }

    /// 清除缓存
    func clearCache() {
        newsCache.removeAll()
        cacheTimestamp.removeAll()
        print("📰 NewsFetcher: Cache cleared")
    }
}