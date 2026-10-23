# 備忘錄 MemoApp（UIKit）

純程式碼 UIKit 備忘錄 App，不使用 Storyboard，最低支援 iOS 27。

## 功能
- 新增、編輯（自動儲存）、刪除備忘錄
- 第一行自動當標題，第二行當預覽
- 搜尋、右滑置頂、左滑刪除
- 分享內容、字數顯示、深色模式
- 文字格式：標題／副標題、粗體、斜體、底線、刪除線、字級大小（鍵盤上方工具列）
- PencilKit 手繪：插入到內文中，點一下可再編輯
- 地點（MapKit）：搜尋、長按地圖標記或使用目前位置，可在「地圖」App 開啟
- Apple Intelligence 分類（Foundation Models）：單則或批次自動分類，也能手動選分類並依分類篩選
- 資料以 JSON 存在 App 的 Documents 資料夾

## 檔案
| 檔案 | 用途 |
|---|---|
| Sources/Note.swift | 資料模型 |
| Sources/NoteStore.swift | 讀寫、排序、刪除 |
| Sources/AppDelegate.swift / SceneDelegate.swift | App 啟動、建立視窗 |
| Sources/NotesListViewController.swift | 列表畫面 |
| Sources/NoteEditorViewController.swift | 編輯畫面 |
| project.yml | XcodeGen 專案設定 |
| .github/workflows/build-ipa.yml | 用 GitHub Actions 編出 IPA |

## 方法一：有 Mac
1. `brew install xcodegen`
2. 在此資料夾執行 `xcodegen generate`
3. 打開 `MemoApp.xcodeproj`，在 Signing & Capabilities 選你的 Apple ID（Team），
   把 Bundle Identifier 改成獨一無二的名稱（例如 `com.你的名字.memoapp`）
4. 接上 iPhone，按 ▶ 直接安裝；或 Product → Archive → Distribute App 匯出 IPA

## 方法二：沒有 Mac（用 GitHub Actions）
1. 在 GitHub 建一個新的 repo，把整個資料夾推上去（分支名稱用 `main`）
2. 到 repo 的 **Actions** 分頁，等「Build IPA」跑完（約 3–5 分鐘）
3. 點進該次執行，在最下方 Artifacts 下載 `MemoApp-unsigned-ipa`，解壓得到 IPA

## 關於簽章
iPhone 只能安裝有簽章的 App。GitHub 產出的是**未簽章 IPA**，需要再用 Sideloadly
或 AltStore 搭配你的 Apple ID 簽章後安裝。免費 Apple ID 簽的 App 7 天後會失效，
需要重新簽；付費開發者帳號（每年 US$99）則可簽一年，也能上架 TestFlight / App Store。
