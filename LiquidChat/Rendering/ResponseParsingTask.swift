//
//  来源：alfianlosari/ChatGPTUI (MIT License, Copyright (c) 2024 Alfian Losari)
//  https://github.com/alfianlosari/ChatGPTUI
//  原文件在库中为 internal，跨模块无法调用；此处复制并提升为 public。
//  完整许可证见同目录 LICENSE-ChatGPTUI。
//

//
//  File.swift
//  
//
//  Created by Alfian Losari on 19/05/24.
//

import ChatGPTUI
import Foundation
import Markdown

public actor ResponseParsingTask {

    public func parse(text: String) async -> AttributedOutput {
        let document = Document(parsing: text)
        var markdownParser = MarkdownAttributedStringParser()
        let results = markdownParser.parserResults(from: document)
        return AttributedOutput(string: text, results: results)
    }

    /// Swift 6 严格并发下，`AttributedOutput`（来自 ChatGPTUI，非 Sendable）
    /// 无法从本actor 直接返回到主线程。此处提供 Sendable 包装中转，
    /// 内部只承载不可变值，语义上等价且不修改上游类型定义。
    public func parseSendable(text: String) async -> SendableAttributedOutput {
        let output = await parse(text: text)
        return SendableAttributedOutput(output)
    }
}

/// `AttributedOutput` 的 Sendable 包装，供跨并发域传递。
public struct SendableAttributedOutput: @unchecked Sendable {
    public let string: String
    public let results: [ParserResult]

    init(_ output: AttributedOutput) {
        self.string = output.string
        self.results = output.results
    }

    /// 回到 ChatGPTUI 的原始类型供MessageRow 使用
    public var attributedOutput: AttributedOutput {
        AttributedOutput(string: string, results: results)
    }
}

