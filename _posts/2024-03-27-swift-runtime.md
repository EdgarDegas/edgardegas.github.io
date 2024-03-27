---
layout: post
title: 记录一次对 Swift 动态的探索
---

# 背景

有不少 iOS 的库依赖 Objective-C 的动态特性，这对于 Swift 用户来说并不舒适。首先你经常需要把类型声明为 NSObject 子类，无法使用 struct / enum 等值类型；经常还必须加上 `@objc` 注释，否则无法将方法动态地暴露给 Objective-C。

有没有办法在纯 Swift 的基础上，进行一定的反射呢？

# Swift.Mirror

Swift 前几年出了一个 `Mirror` API，确实一定程度上提供了这样的能力。

有很多人看见一个新 API 就说“强大”，目前还看不懂 `Mirror` 哪里强大。基本上只能看到成员变量，连赋值也都还不行，更不要说动态派发方法了。

# C

于是我开始在 C/C++ 的层面上找办法。

众所周知，Swift 是基于 C++ 的，在运行时，Swift 的函数会被装载为一个函数指针。于是我们可以通过 `dlsym` 找到这个 symbol：

```c
dlsym(RTLD_DEFAULT, <function name>)
```

那么，现在的思路就是通过传入函数的名称，找到一个函数指针，调用并返回它的返回值：

```c
void* _performMethod(const char* funcName, const void* onObject) {
    void* (*implementation)(void*);
    *(void **) (&implementation) = dlsym(RTLD_DEFAULT, funcName);

    char *error;
    if ((error = dlerror()) != NULL)  {
        printf("CHelper: method not found\n");
    } else {
        return implementation(onObject);
    }
    return NULL;
}
```

兴冲冲地，我把这段函数作为一个 target，包装进我的 Swift Package 中：

```swift
    targets: [
        .target(
            name: "MyLibrary",
            dependencies: [
                "CHelper"
            ]
        ),
        .target(
            name: "CHelper",
            publicHeadersPath: "./"
        ),
    ]
```

但是，发现了两个问题。

第一个，`dlsym` 函数是谁提供的？在 Windows 中，我们是无法调用这个函数的，而应该改成 `<windows.h>` 中的某个方法。在微软[ Xamarin 的相关文档中](https://learn.microsoft.com/en-us/dotnet/api/objcruntime.dlfcn.dlsym)可以看到，它被归类到了 `ObjcRuntime.Dlfcn` 下。

另一个问题在上面这篇文档中也有提到：

> The symbol name passed to dlsym() is the name used in C source code.
>
> If you looking up a C++ symbol, you need to use the **mangled** C++ symbol name.

我们必须传入 mangle 过的符号名。Manging 是编译器对于符号重名问题的解决方案，它将函数的名字和它的参数、返回类型，它所处的命名域等信息收集起来，通过既定的符号映射规则，形成一个独特的符号名。

怎么才能知道一个 Swift 方法的符号名是什么呢？

# Runtime 库

发现了一个库，叫做 Runtime，提供纯 Swift 的反射功能：https://github.com/wickwirew/Runtime

苹果 Swift 官方在公布 `Mirror` 的同时（也可能不是同时），也提供了 Swift 的类型元数据的存放位置，可以看[这篇文档](https://github.com/apple/swift/blob/main/docs/ABI/TypeMetadata.rst)，让我们往下拉，看到 Nominal Type Descriptor 一节：

> The metadata records for class, struct, and enum types contain a pointer to a **nominal type descriptor**, which contains basic information about the nominal type such as its name, members, and metadata layout. For a generic type, one nominal type descriptor is shared for all instantiations of the type. The layout is as follows:
>
> - The kind of type is stored at offset 0, which is as follows:
>   - 0 for a class,
>   - 1 for a struct, or
>   - 2 for an enum.
>
> - The mangled **name** is referenced as a null-terminated C string at **offset 1**. This name includes no bound generic parameters.

看到了吗？ 类型的 mangled name 就存储在这个 descriptor 中，就是从它的第1个比特开始读，读到 null 为止的这个字符串。

但遗憾的是，文档也标注了：

> **Warning: this is all out of date!**

实际使用这个库也确实取不到的类型的 mangled name：

```
(lldb) p try! typeInfo(of: Example.self).mangledName
(String) "Example"
```

再说，最终我们要取到的是函数的符号名，盯着类型的也没用。

# LLDB 符号表

但我们可以先使用 lldb 的查找功能看看。

出于试验目的，我定义了一个 struct，名叫 `ABCDEFGHIJKLMNOPQRSTUVWXYZ`，以便浏览查找结果：

```
(lldb) image lookup -rvs ABCDEFGHIJKLMNOPQRSTUVWXYZ
```

得到了很多结果，比如这个 struct 的初始化函数的信息：

> Function: id = {0x100000471}, 
>
> name = "MyDSBridgeExample.ABCDEFGHIJKLMNOPQRSTUVWXYZ.init() -> MyDSBridgeExample.ABCDEFGHIJKLMNOPQRSTUVWXYZ", 
>
> mangled = "$s17MyDSBridgeExample26ABCDEFGHIJKLMNOPQRSTUVWXYZVACycfC"

由于我是在一个叫 MyDSBridgeExample 的项目里操作的，因此名字前面的 module 名是这样的。可以看到这个 `init()` 最终的 mangle 结果是：“$s17MyDSBridgeExample26ABCDEFGHIJKLMNOPQRSTUVWXYZVACycfC”。

眼睛尖的人可能一眼就看到一个 26，和我们的类型名，从 A-Z 的 26 个字母，正好长度一样；而数字 17 也正好就是 MyDSBridgeExample 的长度。因此数字就是“后X个字符”的意思。

那么前面的 s 是什么意思呢？后面的 VACycfC 是什么呢？

我们再定义几个函数：

```swift
struct ABCDEFGHIJKLMNOPQRSTUVWXYZ {
    func f1() { }
    func f2() { }
}
```

查找符号：

> name = "MyDSBridgeExample.ABCDEFGHIJKLMNOPQRSTUVWXYZ.f1() -> ()", 
>
> mangled = "$s17MyDSBridgeExample26ABCDEFGHIJKLMNOPQRSTUVWXYZV2f1yyF"
>
> 
>
> name = "MyDSBridgeExample.ABCDEFGHIJKLMNOPQRSTUVWXYZ.f2() -> ()", 
>
> mangled = "$s17MyDSBridgeExample26ABCDEFGHIJKLMNOPQRSTUVWXYZV2f2yyF"

可以看到，2f2 和 2f1 之前都有一个 V，那么这个 V 应该是指 struct。

f1 和 f2 只有名字不同，其余都相同的情况下，得到的后缀都是 yyF，那么这应该就是无参数、无返回值的方法的格式了。

# Dl_Info

这时候，在 wickwirew/Runtime 的 Issue 里，我看到另一种解决办法：

```swift
func mangledName(for type: Any.Type) -> String {
   let pointer = UnsafeRawPointer(bitPattern: unsafeBitCast(type, to: Int.self))
   var info = Dl_info()
   dladdr(pointer, &info)
   return String(cString: info.dli_sname)
}
```

试着传入了类型：

```
(lldb)  p mangledName(for: ABCDEFGHIJKLMNOPQRSTUVWXYZ.self)
(String) "$s17MyDSBridgeExample26ABCDEFGHIJKLMNOPQRSTUVWXYZVN"
```

又试了几个基础类型：

```
(lldb)  p mangledName(for: Int.self)
(String) "$sSiN"
(lldb)  p mangledName(for: String.self)
(String) "$sSSN"
(lldb)  p mangledName(for: Void.self)
(String) "$sytN"
```

那么能不能传入函数呢？在这之前，首先函数不是一种 `Any.Type`，那么传入函数的类型呢？

```
(lldb)  p mangledName(for: type(of: ABCDEFGHIJKLMNOPQRSTUVWXYZ.f1))
(String) "_ZL21InitialAllocationPool"
(lldb)  p mangledName(for: type(of: ViewController.viewDidLoad))
(String) "_ZL21InitialAllocationPool"
(lldb)  p mangledName(for: type(of: mangledName))
(String) "_ZL21InitialAllocationPool"
```

不论传入的是哪个函数，最后得到的都是 _ZL21InitialAllocationPool。

再说了，函数的类型，似乎不会和它属于哪个类型有关吧。

弄了半天，一是连函数存储在哪里还不知道，二是 Swift 函数和 C 指针之间似乎并不兼容：

```
unsafeBitCast(ABCDEFGHIJKLMNOPQRSTUVWXYZ.f1, to: Int.self)
// Fatal error: Can't unsafeBitCast between types of different sizes
```

按照论坛上的说法，只有 `@convention(c)` 的函数才可以和指针互相兼容：

> There isn't any way to bitcast a pointer into a Swift function value. If you can make it so that the pointer uses the C calling convention, can you cast to a `@convention(c)` type instead?

# Swift Macro

事实上，苹果已经提供了 [Mangling 规则的文档](https://github.com/apple/swift/blob/main/docs/ABI/Mangling.rst)，根据这个文档，应该是可以做出来一个 mangle 函数的。

下一个问题是，怎么动态地获得函数的从模块到类型（甚至嵌套类型）到函数的完整信息？不用 Runtime 的话，好像也没有什么好办法吧。

也许可以用 Swift Macro？在编译前就可以获取到一个类型的所有的函数信息。如果决定了要用 Macro 的话，其实完全不需要反射。

最后，用 Swift Macro，我做成了这个库：[DSBridge-Swift](https://github.com/EdgarDegas/DSBridge-Swift)，用一种简单粗暴的方式，在静态时获取函数名、参数类型、返回类型等全部信息。
