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

import Foundation
import Markdown

public actor ResponseParsingTask {
    
    public func parse(text: String) async -> AttributedOutput {
        let document = Document(parsing: text)
        var markdownParser = MarkdownAttributedStringParser()
        let results = markdownParser.parserResults(from: document)
        return AttributedOutput(string: text, results: results)
    }
    
}

