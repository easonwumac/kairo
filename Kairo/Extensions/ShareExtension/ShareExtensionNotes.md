# Share Extension Notes

這個資料夾預留給 Xcode Share Extension target。

建議 flow：

1. 接收 `NSExtensionItem`。
2. 支援 plain text、URL、PDF/file URL、image。
3. 顯示簡短 UI：
   - Save to Memory
   - Summarize
   - Extract Tasks
   - Ask About This
4. 將內容寫入 App Group container。
5. 長工作交給主 App 或後端，不要在 extension 內做重模型推理。

注意：Share Extension 執行時間和記憶體有限，必須快速完成。
