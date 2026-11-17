# 113 · Card B · iOS student standalone chat video

**当前结论（2026-11-17）**：主代理已收货 iOS 本地实现，独立 Standards / Spec CLEAN，原生构建、Networking 159 / ChatUI 100 / StudentKit 1327 项测试及 17e 浅深色实际流程通过。交 T2 PR 等 David，不自合；真实后端 / OSS 跨端联调尚未执行。下文早期 handoff、磁盘满与模拟器替换记录是过程证据，最终状态以末尾验收记录为准。

- Worktree: `/Users/david/.codex/worktrees/student-chat-video-ios/MeetPR-release`
- Branch: `feat/113-student-chat-video`; base `c693abab729a8f92340178780a90a6822c92b304`.
- Owner: delegated Codex iOS writer. No commit/push. Main agent assumes validation/review after this handoff.
- Source: approved SPEC and approved HTML, no product decisions reopened.

## Implementation

- Student + menu: native single-video PhotosPicker, owned temporary copy, MP4/MOV <= 200 MiB validation, local AVPlayer preview, choose again/cancel/send with recipient, localized zh-Hans/zh-Hant/en.
- ChatSendCoordinator session outbox owns file after confirm, bounded-upload progress, failed retry retains same clientID/file; successful message confirmation and session drain remove local copies. Text remains sendable.
- NetworkChatRepository uploads 5 MiB parts with verified part order/ETags and byte-based progress, then posts `kind=text`, fixed `body=[视频]`, `video_id`, `client_id` without set/exercise reference. Upload or POST failure uses existing abort/delete/reconcile cleanup.
- Optional response videoID preserves old message-kind decoding. Only text + videoID and no set/exercise reference is standalone. Existing training-set message shape stays unchanged (backend omits video_id).
- Shared video card on student and coach timeline, duration/poster, explicit unavailable card; exact-message renewal supports missing/expired URLs. Player reuses existing refresh mechanism.
- Demo InMemory repository keeps a separate playable copy until repository deinit, deduplicates clientID.

## Red → green evidence

Logs in `docs/journal/113-ios-evidence/`:
- DTO standalone old-kind compatibility: `ios113-red.txt` (missing API), `ios113-green.txt` (1 passed).
- 5 MiB multipart + wire request: `ios113-upload-red.txt` (invalidAttachment default), `ios113-upload-green.txt` (2 passed).
- Outbox retry/file cleanup: `ios113-outbox-red.txt` (missing video API), `ios113-outbox-green.txt` (2 passed).
- Missing-URL renewal: `ios113-renew-red.txt` (unavailable), `ios113-renew-green.txt` (1 passed).
- Demo playback copy: `ios113-demo-red.txt` (invalidAttachment), `ios113-demo-green.txt` (1 passed).
- Initial outbox implementation hit Swift exclusivity during dictionary replacement; fixed by computing replacement from current item before mutating the dictionary. Final green log above.
- `swiftlint lint --strict` all 24 changed/new Swift files: 0 violations, `ios113-lint.txt`. `git diff --check`: clean.
- Added failure-phase upload cleanup tests (part/complete/send); included in pending full Networking run.

## Pending verification / precise handoff

No simulator screenshot yet. Code frozen for independent review; UI behavior and full build are NOT claimed verified.

Running shell sessions (read logs for results; session IDs usable if tool session is shared):
- ChatUI full: 50142, `/tmp/ios113-ChatUI-all.log`
- Networking full: 89592, `/tmp/ios113-Networking-all.log`
- StudentKit full: 93857, `/tmp/ios113-StudentKit-all.log`
- Commands: `swift test --package-path Modules/<ChatUI|Networking|StudentKit> --jobs 4`.
- Earlier broad test attempts aborted because format edits changed files mid-build; final runs above were started after code freeze. StudentKit run began slightly earlier; rerun if it reports input-modified.

XcodeBuildMCP compile-only `build_sim({})` running in functions cell `g5:53`; DerivedData `/tmp/MeetPR-ios113-derived`.
Defaults: project this worktree `MeetPR.xcodeproj`, scheme `MeetPR-DemoStudent`, configuration `DemoStudent`, extraArgs `[-jobs,4]`.
Expected app `/tmp/MeetPR-ios113-derived/Build/Products/DemoStudent-iphonesimulator/MeetPR.app`.
Simulator ONLY iPhone 17e iOS 26.5 UUID `5D5FA360-BA49-48C6-A887-2F0D22F89749`.
Earlier own build_run was interrupted before install to observe 17e queue; build log `/Users/david/Library/Developer/XcodeBuildMCP/workspaces/lai-o-612e1c77f2e2/logs/build_run_sim_2026-11-17T11-29-08-455Z_pid73282_4d159dcd.log`.
Another session's `/Users/david/Projects/apps/MeetPR-wt-112` xcodebuild was active. Do not touch its process, install on 17e only after it is free; no 17/17 Pro use.

Next steps:
1. Read final test logs and build result; fix any compiler/test errors, rerun affected checks.
2. After queue is free, XcodeBuildMCP `session_show_defaults`, set this project/scheme/config/17e if necessary, then install app via `install_app_sim` or build_run_sim. Get bundle ID from app using tool and set defaults, launch.
3. Seed 17e gallery with repo `docs/evidence/107-row-motion/after.mp4` if needed (no add-media MCP tool is exposed, use narrow simctl addmedia fallback). Screenshot + menu, video-only picker, preview cancel/reselect, confirmed video card and playback in DemoStudent. No fake network proof: Demo uses InMemory repository.
4. Coach shared card requires Demo coach fixture or test-backed screenshot; actual backend interoperability/OSS transport remains root's integration acceptance.
5. Run Standards/Spec independent review (root owns); append results and final evidence here.

Tools exposed snapshot_ui and screenshot but no tap/swipe. Native CUA or installed simulator automation CLI is needed for interactions; no UI actions have been taken yet. All changed source paths are visible in git diff/status, new files included. No credentials used.

### Final handoff update

At handoff the ChatUI and Networking full builds both report `No space left on device`; neither full suite has passed. Root notified to reclaim safe build-cache space and rerun. Own compile-only Xcode PID 89010, log `/Users/david/Library/Developer/XcodeBuildMCP/workspaces/lai-o-612e1c77f2e2/logs/build_sim_2026-11-17T11-34-05-448Z_pid73282_0dec61dc.log`; wt112 was no longer in xcodebuild process listing. Do not interpret compiler I/O failures as feature assertion failures.

### Review fixes / resumed native acceptance

- Spec P3: pending video card now shows known local duration at bottom-right during uploading and failed states, matching delivered-card style. `ios113-pending-duration-lint.txt`: 0 violations.
- Native Xcode first resumed build found generated xcstrings symbol collision (`chat.video.unavailable` vs legacy `chat.videoUnavailable`). Renamed only new key/reference to `chat.standaloneVideoUnavailable`; string values unchanged. SwiftPM cannot detect this Xcode string-symbol generation issue. Incremental native build rerun.
- After space recovered, root owns final full module tests in `/tmp/ios113-*-final.log`; this child does not duplicate those runs.
- 17e queue checked free; a valid repository MP4 was added to its gallery using simctl addmedia because exposed MCP simulator-management tools have no add-media capability. UI tap and appearance controls use XcodeBuildMCP CLI since those tools are not exposed through current MCP session.

### Independent review closure

Root reports Standards and Spec round-1 reviews both CLEAN. Pending-duration P3 is closed. Networking 159 and ChatUI 100 final tests passed; StudentKit is still compiling under root session 60558. Evidence uses tracked `.txt` files. Full package output is retained in adjacent `.txt.gz` archives with SHA256 and a readable final excerpt; original temporary paths above are execution references, not the delivery source.
- Native compile then exposed an internal ChatUI presentation helper referenced from StudentKit. The standalone video receipt now uses StudentBlackGoldChatView's existing localized read/delivered strings; standalone row extracted to keep lint body length. No product behavior change. Native incremental build rerun.
- NEXT-RELEASE now records spec 113 under a separate pending-merge candidate section (P1/T2, David merge, backend #429/0089 deployment and real OSS cross-platform acceptance required, not packaged); build 42 target and RELEASES unchanged.


## Final native / simulator evidence (12:02 handoff checkpoint)

- Final native DemoStudent build **SUCCEEDED**; XcodeBuildMCP client timed out at 300 seconds but underlying build completed normally. `native-build-final.txt` records successful tail and full log source. Installed and launched on iPhone 17e only.
- Root final suites: Networking **159**, ChatUI **100**, StudentKit **1327 / 94 suites**, all passed. Tracked text logs: `Networking-final.txt`, `ChatUI-final.txt`, `StudentKit-final.txt`.
- Actual 17e flow: + menu video entry → system video-only gallery → choose owned test MP4 → local preview → choose again returns gallery → reselect → cancel returns chat with no new video → select again/send → standalone card duration **0:02**, delivered receipt → tap plays the actual video in existing player. Video content is repository UI recording test media, not real account data. Demo uses local InMemory repository; this proves UI/lifecycle, NOT live OSS upload.
- Images personally viewed: `01-menu-light.jpg`, `02-video-picker-light.jpg`, `03-preview-light.jpg`, `04-delivered-light.jpg`, `05-playback-light.jpg`. Also copied to `/Users/david/Documents/Codex/2026-11-17/lai-o/outputs/113-ios-<filename>`.
- Image name corrected from initial mistaken `01-menu-dark.jpg` to `01-menu-light.jpg`; all current evidence is actually light. System dark setting did not change app's persisted light preference.
- A small observation: after instantaneous Demo send/confirmation, the newest card was below the viewport and required one upward swipe to fully view. Root notified; no scroll code changed.
- **Deep-color acceptance blocked by competing installation:** immediately after playback screenshot, 17e suddenly showed `restRing.button` (absent from this worktree), and installed binary hashes differed. Built `MeetPR.debug.dylib` SHA256 `8ea924cdb761d8a286a6cc155459f7cbb117fc8d0a6017121be51267390b29f1`; installed dylib SHA256 `5127e6129b3e388d219c51a30785a74e297901e39a8727e39e68cef60128c543`. Simulator actions paused to avoid replacing another task's active build. No screenshot after replacement is claimed as this feature's evidence.
- Remaining: dark app-theme UI, coach live receipt/cross-platform real OSS, actual backend deployment gate. No release, commit, push, or version bump performed by child.


## Final QA closure (12:08)

The dark-mode blocker above is resolved. Root authorized a separate temporary simulator QA package to avoid replacing another task's app. Copied the already compiled .app to `/tmp/MeetPR-ios113-QA/MeetPR.app`, changed only temporary bundle IDs (`com.meetpr.chatvideoqa`, corresponding widget prefix), display name (MeetPR Chat Video QA) and ad-hoc signatures. Repository project/bundle ID/version/signing unchanged. QA installation succeeded. Its installed `MeetPR.debug.dylib` SHA256 exactly matches the original compiled implementation: `8ea924cdb761d8a286a6cc155459f7cbb117fc8d0a6017121be51267390b29f1`.

Waited until the other task's screen remained unchanged and no UI input commands were active; launched QA at 12:05, changed QA's own Settings → Appearance → Dark, then repeated + video → video-only gallery → preview → send. Personally inspected screenshots `06-menu-dark.jpg`, `07-video-picker-dark.jpg`, `08-preview-dark.jpg`, `09-delivered-dark.jpg`, also exported as `/Users/david/Documents/Codex/2026-11-17/lai-o/outputs/113-ios-<filename>`. In the independent QA run, the delivered card and 0:02 duration were visible immediately after send; the earlier scroll observation did not reproduce. Stopped only `com.meetpr.chatvideoqa` at 12:08, releasing 17e. No 17 / 17 Pro installs.

Final local result: native build passed; 159 Networking + 100 ChatUI + 1327 StudentKit tests passed; Standards/Spec CLEAN (root reported); light/dark menu, gallery, preview, sent card inspected; cancel/reselect/send/playback exercised. Outstanding integration remains real deployed backend/OSS and coach/cross-platform receipt, as recorded in NEXT-RELEASE. Source frozen; no child commit/push.

## 合并与真实联调准备（2026-11-17）

David已批准合并、后端备份/0089/部署及双端真实联调。#478已squash到release/1.0@c3c1b34ef705deeb25ffe2971fbb633d02de0528；合并前CI三项全绿（44080694507）。以合并SHA准备Debug真实网络构建，目标iPhone17e；不使用Demo作为持久化证明。后端控制台连续连接超时，真实备份/迁移/部署及已绑定测试登录会话尚缺。没有Archive/上传，build号保持41，候选仍为42。

Debug真实网络构建通过（282.9s，XcodeBuildMCP build_sim）；独立QA产物bundleId `com.meetpr.chatvideoliveqa`，只修改复制产物的Info.plist并adhoc签名，源码与正式签名配置未改。MeetPR.debug.dylib SHA256保持 `180462259a42120d4fe626ce13b6758533c6099ccfdab709f62b7b78d8a7dd3f`。已在iPhone17e安装/启动，显式API base为国内staging；尚待已绑定测试师生登录与0089部署。
