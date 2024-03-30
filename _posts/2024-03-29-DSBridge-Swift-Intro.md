---
layout: post
title: DSBridge-Swift
disc_url: https://github.com/EdgarDegas/edgardegas.github.io/discussions/11
category: repo
---

大家好，今天介绍我新写的一个开源库：[DSBridge-Swift](https://github.com/EdgarDegas/DSBridge-Swift)，它是 DSBridge-iOS 的一个 Swift 翻新版。

DSBridge-iOS 是一个深受大家喜爱的 JavaScript Bridge，尽管已经尘封 6 年，但仍然广为人所用，也有不少新的 Issue。目前它面临一个比较大的问题，那就是 iOS 系统迭代。比如 iOS 16.4 推出的新 API：

```swift
@available(iOS 16.4, *)
func webView(
    _ webView: WKWebView,
    willPresentEditMenuWithAnimator animator: any UIEditMenuInteractionAnimating
) {
        
}
```

即便你设置了 `dsuiDelegate` 并且实现了这个方法，在网页选中文本、弹出编辑栏的时候，这个方法仍然不会被调用。原因是按照 DSBridge-iOS 的设计，`WKUIDelegate` 中任何一个方法都必须先在 `DWKWebView` 中实现一遍，它才可能转发给你的 `dsuiDelgate`。

因为上述原因，这个库必须要通过修改自身的源码才能匹配 iOS 系统的更新。这不符合[开闭原则]({% post_url 2024-02-04-再谈SOLID原则 %})。

DSBridge-Swift 选择不站在开发者和 `WKWebView` 之间。DSBridge-Swift 的 `DSBridge.UIDelegate` 只做了一件事，就是捕获来自 JS 的调用，而将其他的代理方法全部转发给开发者自己设置的 `WebView.uiDelegate`，由开发者自己决定是否实现、怎么实现。

因此也就没有 `dsuiDelegate` 了，直接设置 `uiDelegate` 就可以了。

DSBridge-iOS 默认会为你实现 `alert`、`confirm` 和 `prompt` 的弹窗，但目前的局面就是，它所使用的 `UIAlertView` 已经被 iOS 弃用了。出于和上面同样的原因，DSBridge-Swift 选择由开发者自己实现这些响应，比如通过设置 `uiDelegate`，并实现 `runJavaScriptConfirmPanelWithMessage`、`runJavaScriptAlertPanelWithMessage` 和 `runJavaScriptTextInputPanelWithPrompt` 来弹出弹窗。

一句话概括就是： `DSBridge.WebView` 是一个原汁原味的 `WKWebView`。

# 动态 VS 静态

在原来的 DSBridge-iOS 中，你的 JavaScript Object 必须是 NSObject 子类，且每个你要暴露给 JS 的方法都需要标注 `@objc`。

在新的 DSBridge-Swift 中，你可以用纯 Swift 的类而不需要继承 `NSObject`：

```swift
@Exposed
class MyInterface {
    func returnValue() -> Int { 101 }
    @unexposed
    func localMethod()
}
```

只需要加上 `@Exposed` 宏就能将你的类型暴露给 JS。不想暴露的方法则加上 `@unexposed` 标注即可。

既然我们已经绕过了动态，那你甚至可以用 `struct` 和 `enum` 来声明你的 Interface（对，JavaScriptObject 现在改名叫 Interface）：

```swift
@Exposed
enum EnumInterface {
    case onStreet
    case inSchool
    
    func getName() -> String {
        switch self {
        case .onStreet:
            "Heisenberg"
        case .inSchool:
            "Walter White"
        }
    }
}
```

这就声明了一个非常漂亮的一体两面的接口集，提供 `getName` 接口。

其他比如参数、返回值、回调等，以及如何调用，都和[原库一样](https://github.com/wendux/DSBridge-IOS/blob/master/readme-chs.md#使用)。

# 基本原理与开闭原则

前面我们提到了[开闭原则]({% post_url 2024-02-04-再谈SOLID原则 %})，DSBridge-Swift 充分遵从了开闭原则。

首先 DSBridge-Swift 的 `DSBridge.WebView` 中几乎没有逻辑，所有逻辑都在作为中枢的拱心石 `Keystone` 中。

> **拱心石**（英语：Keystone），是砖石[拱](https://zh.wikipedia.org/wiki/拱)门顶上的楔形石头以及圆形石头。这些石块是施工过程中最后一块安放的石头，它主要能将所有的石头固定在位置上。 -- [维基百科](https://zh.wikipedia.org/wiki/拱顶石)

## 解析来自 JS 的调用

你可以修改 `Keystone` 的 `jsonSerializer` 和/或 `methodResolver`：

```swift
(webView.keystone as! Keystone).jsonSerializer = MyJSONSerializer()
(webView.keystone as! Keystone).methodResolver = MyMethodResolver()
```

这两个对象负责将来自 JS 的调用转化为 `IncomingInvocation`（DSBridge-Swift 对于来自 JS 的调用的封装）。

想用 SwiftyJSON 或者 HandyJSON？想修改传参格式？没问题，修改 `jsonSerializer` 就行。

还有比如 DSBridge-Swift 仅在开发环境中打印 JSON 序列化报错的详情；生产环境中，具体的对象或 JSON 字符串会被替换为`*hashed*`或者一个空对象。如果你希望改变这一行为，你可以自己定义错误类型，而不使用 `DSBridge.JSON` 之下的。

## Native 调用 JS

`Keystone.javaScriptEvaluator` 负责管理所有发向 JS 的消息，仿照 DSBridge-iOS，它每 50ms 才执行一次 JS 脚本，避免执行过于频繁，被 iOS “丢包”。原来的 DSBridge-iOS 只针对回调（响应来自 JS 的异步调用）做了优化，[Native 主动调用仍然会出现丢包](https://github.com/wendux/DSBridge-IOS/issues/154)；DSBridge-Swift 则对于 Native 的主动调用也做了等待队列。

如果你需要做进一步的优化，或者不想要这样的优化，还原本来的体验，你完全可以将 `Keystone.javaScriptEvaluator` 替换掉。

## 派发来自 JS 的调用

`Keystone.invocationDispatcher` 负责管理所有你注册的 Interface，并负责派发 `IncomingInvocation`，你可以替换它，提供你自己的实现。

## 日志

DSBridge-Swift 的大部分日志都是通过 `DSBridge.sharedLogger()` 打印的，它调用 os_log API，不仅可以从 Xcode 控制台看到打印，也可以在系统的比如 macOS 的控制台流式传输。

为了符合开发者对 DSBridge-iOS 的原本行为的预期，以及为了匹配调用的数据结构，我们难以抛出、传递和处理错误。包括新增的 Native 调用 JS 的 `call(_:with:thatReturns:completion:)` API，尽管 `completion` 返回的是一个 `Result<T, any Swift.Error>`，但也只是返回调用过程中的错误，Native 和 JS 之间并不能互相认错。

因此 DSBridge 将重度依赖日志。通过替换 `DSBridge.sharedLogger()` ，你可以提供自己的 `DSBridge.ErrorLogging`，在测试中把打印出的错误用弹窗展示，或者在生产环境中将日志上报到平台等。

## 拱心石

有了上面这样的可扩展性，你甚至可以修改 JS 端的代码，而无需修改 DSBridge-Swift 的源码。

在这之上，你甚至可以重新定义自己的拱心石，完全替换掉从接收来自 JS 的原始字符串之后的所有逻辑。这需要你实现 `DSBridge.KeystoneProtocl`，你可以利用或舍弃 DSBridge-Swift 中的现成实现，打造一个完全不同的 Bridge。
