# README

当前代码未验证与Python交互, 需要Python验证交互逻辑完成之后, 当前`SDK`修改同步逻辑, 完成最终交互



# 主工程

## `AudioTap`

主工程, `SDK`

#### 音频录制参数

```
<AVAudioFormat 0x6000023aec60:  2 ch,  48000 Hz, Float32, interleaved>
```

#### 代码层

```
# 核心代码 AudioTap->Taps
- AudioTap
  - Taps
    - AudioMotion.swift
      - 外部调用使用
      - startRecord 开启录音
      - stopsRecord 关闭录音
    - AudioProcess.swift
      - 模型
    - AudioProcessController.swift  
      - 系统音频类进程获取
    - AudioProcessTap.swift
      - 系统音频进程处理类
    - AudioProcessTapRecorder.swift
      - 录音管理
    - AudioRecordingPermission.swift
      - 权限管理类
  - Common
    - Config.swift
  - Extension
    - 扩展
- AudioTap.xcodeproj
```

#### 与Python交互

核心代码存在于`AudioProcessTapRecorder.swift`=>`line93`

- 直接存储本地
- 转换成Data, 之后进行处理进程通信等都可以

```
try tap.run(on: self.queue) { [weak self] inNow, inInputData, inInputTime, outOutputData, inOutputTime in
    guard let self, let currentFile = self.currentFile else {
        return
    }
    do {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: inInputData, deallocator: nil) else {
            throw "Failed to create PCM buffer"
        }
        // 录制存储文件到本地
        try currentFile.write(from: buffer)
        /*
         // 存储Data回调外部使用
         if let mdata = inInputData.pointee.mBuffers.mData {
             let data = Data(bytes: mdata, count: Int(inInputData.pointee.mBuffers.mDataByteSize))
             print("record buffer success:")
         }
         */
    } catch {
        self.logger.error("\(error, privacy: .public)")
    }
} invalidationHandler: { [weak self] tap in
    guard let self else {
        return
    }
    self.handleInvalidation()
}
```



### `AudioTapExample`

调用演示示例



## 示例工程

- Examples
  - AudioCap.zip
    - 独立的文件录制 (纯粹Swift, 验证修改后可以录制)
  - CapturingSystemAudioWithCoreAudioTaps.zip
    - 苹果官网录制 (牵扯混编, 可以参考)



## 参考

````
# search
https://www.google.com.hk/search?q=swift+macos+how+to+record+system+audio&newwindow=1&client=safari&sca_esv=0095a0363d02a90b&sxsrf=AHTn8zpDeWl7_MT8umD0FiJrkDvAjRoL4g%3A1739760841247&ei=yaSyZ8foDsKBvr0PyN6N2A8&ved=0ahUKEwiH8b6X2smLAxXCgK8BHUhvA_sQ4dUDCBE&uact=5&oq=swift+macos+how+to+record+system+audio&gs_lp=Egxnd3Mtd2l6LXNlcnAiJnN3aWZ0IG1hY29zIGhvdyB0byByZWNvcmQgc3lzdGVtIGF1ZGlvMggQABiABBiiBDIFEAAY7wUyBRAAGO8FMgUQABjvBTIFEAAY7wVIuy5QsBxYjyxwAXgBkAEAmAHYAaABhgeqAQUwLjUuMbgBA8gBAPgBAZgCBKACjgPCAgoQABiwAxjWBBhHwgIEECMYJ5gDAIgGAZAGCpIHAzEuM6AH1xE&sclient=gws-wiz-serp

# stack flow
https://stackoverflow.com/questions/56333940/record-audio-on-osx-avaudiosession-not-available

# government link
https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps

# help link
https://forums.developer.apple.com/forums/thread/722958

# AudioCap
https://github.com/insidegui/AudioCap
````

