//
//  来源：alfianlosari/ChatGPTUI (MIT License, Copyright (c) 2024 Alfian Losari)
//  https://github.com/alfianlosari/ChatGPTUI
//  原文件在库中为 internal，跨模块无法调用；此处复制并提升为 public。
//  完整许可证见同目录 LICENSE-ChatGPTUI。
//

import ChatGPTUI
import SwiftUI
import Markdown

public enum HighlighterConstants {
    public static let color = Color(red: 38/255, green: 38/255, blue: 38/255)
}

public struct CodeBlockView: View {
    
    public let parserResult: ParserResult
    @State public var isCopied = false
    
    public var body: some View {
        VStack(alignment: .leading) {
            header
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(red: 9/255, green: 49/255, blue: 69/255))
            
            ScrollView(.horizontal, showsIndicators: true) {
                Text(parserResult.attributedString)
                    .padding(.horizontal, 16)
                    .textSelection(.enabled)
            }
        }
        .background(HighlighterConstants.color)
        .cornerRadius(8)
    }
    
    public var header: some View {
        HStack {
            if let codeBlockLanguage = parserResult.codeBlockLanguage {
                Text(codeBlockLanguage.capitalized)
                    .font(.headline.monospaced())
                    .foregroundColor(.white)
            }
            Spacer()
            button
        }
    }
    
    @ViewBuilder
    public var button: some View {
        if isCopied {
            HStack {
                Text("Copied")
                    .foregroundColor(.white)
                    .font(.subheadline.monospaced().bold())
                Image(systemName: "checkmark.circle.fill")
                    .imageScale(.large)
                    .symbolRenderingMode(.multicolor)
            }
            .frame(alignment: .trailing)
        } else {
            Button {
                let string = NSAttributedString(parserResult.attributedString).string
                #if os(macOS)
                NSPasteboard.general.setString(string, forType: .string)
                #else
                UIPasteboard.general.string = string
                #endif
                
                withAnimation {
                    isCopied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isCopied = false
                    }
                }
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .foregroundColor(.white)
        }
    }
}
