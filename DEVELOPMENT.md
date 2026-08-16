# 开发指南

本文面向本仓库的维护者，说明构建流水线的工作原理、如何添加插件、如何发版，以及本地验证方法。

## 项目结构

```
.
├── .github/workflows/
│   ├── build.yml       # 主构建流水线：查询版本 → 基础镜像 → 编译 → 推送镜像
│   ├── version.yml     # Release 工作流：推送 v* tag 时自动创建 Release
│   └── readme.yml      # README 同步工作流：推送到 Docker Hub 仓库描述
├── plugins.json        # 插件清单（唯一数据源，构建矩阵由此生成）
├── VERSION             # 版本号（发版时 tag.ps1 的唯一读取来源）
├── versions.sh         # 版本检查 + 构建矩阵生成（versions job 的逻辑）
├── set-versions.sh     # 写入本次构建的 Caddy/插件版本和镜像版本 label（build job）
├── set-base-digests.sh # 查询上游 alpine/debian 按架构 digest（base job，注入 base 镜像）
├── check-base.sh       # 判断基础镜像是否需要重建（base job 的逻辑）
├── build-caddy.sh      # xcaddy 编译 amd64/arm64 二进制
├── write-manifest.sh   # 写入构建清单（finalize job）
├── sync-readme.sh      # 同步 README 到 Docker Hub（readme.yml 的逻辑）
├── tag.ps1             # 本地打 tag 脚本（推送 tag 触发 Release）
├── Dockerfile          # 运行镜像：仅注入对应架构二进制，静态层来自 Dockerfile.base
├── Dockerfile.base     # 静态基础镜像：依赖 + Caddyfile + 环境变量 + 启动命令
├── Caddyfile           # 默认配置（占位）
├── CHANGELOG.md        # 版本更新日志
└── README.md           # 面向使用者的说明
```

## 构建流水线（build.yml）

每天 UTC 17:00（北京时间凌晨 1:00）自动触发，也可在 GitHub Actions 页面手动触发（`workflow_dispatch`，可选 `force_build=true` 强制忽略版本缓存重建所有镜像）；推送 `v*` 格式的 tag 也会触发——`vX.Y.Z-beta.N` 按 beta 模式构建，`vX.Y.Z` 稳定版按生产模式构建，且 **tag 触发视为强制构建**（插件与 base 镜像全部重建，不受跳过逻辑约束）

### 1. versions job —— 版本检查

- checkout 后读取根目录 `plugins.json`，先做一次合法性校验（必须是非空数组）
- 用 `go list -m ...@latest` 查询 Caddy 和每个插件的最新版本
- 输出三个值：
  - `caddy`：Caddy 版本号
  - `matrix`：JSON 数组，每个元素是 `{name, context, plugin_version}`，作为下游矩阵
  - `base_changed`：上游基础镜像（Alpine/Debian）digest 是否与上次构建时不同（`true`/`false`）

插件版本查询全部集中在这里，矩阵 job 不再单独查版本。任一插件查询失败会立刻让整个工作流失败，方便尽早发现问题。

### 2. base job —— 静态基础镜像

每次运行都会执行（步骤很轻，只有 checkout + 登录 + 检查），但**只在必要时真正构建**：

- 检查逻辑（`Check if base image needs rebuild`）：
  - `versions` job 输出的 `base_changed` 为 `true`（上游基础镜像有更新）
  - 手动触发时勾选了 `force_build`
  - `docker manifest inspect` 发现 GHCR 上对应 tag 缺失（首次运行或镜像被删时的自愈）
  - 以上任一成立就重建，否则跳过后续构建步骤
- **构建**：用 `Dockerfile.base` 多架构（amd64/arm64）构建 `ghcr.io/blazesnow/caddy-base:alpine-3.24` 和 `:debian-trixie-slim` 两个静态镜像（仅推 GHCR，不推 Docker Hub），内容是依赖、Caddyfile、环境变量和启动命令等固定层
- 静态层构建一次后，上游基础镜像不变时不会再重复执行 `apk`/`apt-get`（含 arm64 的 QEMU 模拟），这是与之前每个插件各自装依赖的最大区别

### 3. build job —— 动态矩阵构建

- `matrix.include` 用 `fromJSON(needs.versions.outputs.matrix)` 动态生成，每个插件一个 job，并 `needs: [versions, base]`，保证基础镜像就绪
- **跳过判断**：在 `versions` job 由 `versions.sh` 完成——插件版本、基础镜像指纹都没变的插件不会进入 matrix，build job 只有在 matrix 非空时才会运行（`if: needs.versions.outputs.matrix != '[]'`），避免版本没变就重复编译
- **编译**：`xcaddy build` 产出 `linux/amd64`、`linux/arm64` 两个二进制（CGO 关闭）
- **推送**：Docker Buildx 多架构构建，`Dockerfile` 从 `ghcr.io/blazesnow/caddy-base` 继承、仅注入二进制（`COPY --chmod`，无 RUN 层），推送到 Docker Hub（`blazesnow/caddy`）和 GHCR（`ghcr.io/blazesnow/caddy`），每个插件打 `<插件>-alpine` 和 `<插件>` 两个 tag。插件镜像没有任何 RUN 步骤，多平台构建不需要 QEMU（只有 base job 需要）
- 镜像会写入 `org.opencontainers.image.version` label（由 build job 以 build-arg 注入）：生产镜像用 `VERSION` 文件的正式版号；beta 镜像不携带正式版号——beta tag 触发时用 tag 名（如 `1.4.4-beta.1`），dev 分支触发时为 `dev`。同时写入 `org.opencontainers.image.base.name`（基础镜像引用）、`caddy-version` 和 `plugin-version` label（本次构建的 Caddy 版本和插件版本），`docker inspect` 即可查看镜像构成
- base 镜像写入 `base-upstream-digest-amd64` / `base-upstream-digest-arm64` label（上游 alpine/debian 对应架构的 digest，由 base job 用 `set-base-digests.sh` 查询注入），插件镜像继承。这些 label 本身就是"构建记录"——后续可直接对比当前上游 digest 判断是否需要重建，替代 cache 中的 manifest 记录
- 构建完成后由 `finalize` job 用 `write-manifest.sh` 把本次各插件版本和基础镜像指纹写入 `.build-cache/manifest.json` 并缓存，供下次跳过判断使用

### 4. 注意事项

- 所有 job 串行执行（`max-parallel: 1`），主要顾虑是 Docker Hub 推送速率
- `setup-go` 已关闭内置缓存（`cache: false`），仓库没有 go.mod，内置缓存无法计算 key；改为在 build job 手动缓存 Go 模块（`~/go/pkg/mod`，key 为 `go-mod-<Caddy版本>`），Caddy 版本不变时 25 个 job 共享一份依赖下载
- 同时在 build job 缓存 Go 编译缓存（`~/.cache/go-build`，key 为 `go-build-<Caddy版本>-<Go版本>`，Go 版本由 `go env GOVERSION` 运行时解析）。编译缓存内容寻址、与插件无关，Caddy 核心代码的编译产物在 25 个 job 间复用，全量重建（如 Caddy 升级）时只有第一个 job 全量编译，其余 job 只需编译各自插件包；Go 工具链升级会自动换 key 触发重编，不会用上过期的缓存
- 基础镜像只推 GHCR，插件镜像推 Docker Hub 时首次会带上基础镜像的层，同一 registry 内按 digest 去重，之后不会重复上传
- 上游基础镜像 tag 升级时，记得同步更新 `BASE_ALPINE` / `BASE_DEBIAN` 以及 `BASE_TAG_ALPINE` / `BASE_TAG_DEBIAN` 四处的版本号（base job 会检测到 digest 变化并重建）
- GitHub Actions 缓存按 ref 作用域隔离：**只有默认分支（main）上创建的缓存对所有 ref 可见**，dev 分支（beta）创建的缓存，tag 推送触发的运行访问不到。因此 beta tag 运行时 `build-manifest` / `go-build` 缓存会 miss（首个 job 全量编译并把缓存写入该 tag 作用域，插件全部重建一次）；manifest 缺失时 `base_changed` 不会强制重建 base，基础镜像是否缺失由 `check-base.sh` 的镜像存在性检查兜底。main 跑过新管线后 `go-mod` / `go-build` 会存到 main，tag 运行即可命中

### 5. 开发版（beta）镜像

- **beta 模式的触发方式**：在 Actions 页面手动触发工作流并选择 dev 分支，或推送 `vX.Y.Z-beta.N` 格式的 tag。此时镜像推送到 `blazesnow/caddy-beta`（GHCR 为 `ghcr.io/blazesnow/caddy-beta`），tag 结构与生产一致；**其余触发**（定时、main 分支手动、稳定版 tag）构建生产镜像 `blazesnow/caddy`
- 镜像前缀由 workflow 级 env 的 `IMAGE_PREFIX` / `GHCR_IMAGE_PREFIX` 控制（按 `github.ref` 判断），beta 与生产的 **manifest 缓存相互独立**（`CACHE_NS`），互不影响跳过判断
- 基础镜像同样按分支隔离：beta 模式的 base tag 带 `-beta` 后缀（`BASE_TAG_SUFFIX`），不会覆盖生产基础镜像
- beta 模式**只考虑 `BETA_PLUGINS` 指定的少量插件**（默认 cloudflare / tencentcloud / webdav，可自行修改），与生产一样参与 manifest 跳过判断（版本或基础镜像指纹未变则跳过），需要强制重建时勾选 `force_build`
- 开发版用于测试 dev 分支上的构建流水线和插件改动，不产生 GitHub Release；发版仍走 main 分支 + `tag.ps1` 流程

## 添加 / 修改插件

1. 编辑 `plugins.json`，按现有格式加一行（或改一行），例如：

   ```json
   { "name": "example", "context": "github.com/caddy-dns/example" }
   ```

2. 用 `jq .` 格式化后提交（仓库统一 LF 换行，见 `.gitattributes`）
3. 合并推送后，等定时构建或手动触发工作流，会自动生成对应的镜像 tag

> `name` 是镜像 tag 后缀，需保持唯一；`context` 是 Go 模块路径。

## 发布新版本

`version.yml` 已改为：**推送 `v*` 格式的 tag 时自动创建 GitHub Release**，无需手动操作页面。

1. 更新 `VERSION` 文件（写入要发布的版本号，这是发版版本的唯一来源）；同时在 `CHANGELOG.md` 顶部加当前版本的记录（手工维护，无需与 VERSION 严格对齐）
2. 提交并推送代码
3. 运行发布脚本：

   ```powershell
   .\tag.ps1          # 自动读取 CHANGELOG.md 最新版本
   .\tag.ps1 -Tag v1.5.0   # 或显式指定
   ```

4. 脚本会先询问是否发布正式版（输入 `y` 为正式版，其他任意内容为 beta 测试版），再打印将要执行的操作，输入 `y` 确认后创建并推送 tag（`-NoPush` 只打 tag 不推送）
5. 推送成功后，Actions 的 Version 工作流会自动创建 Release，build.yml 同时触发构建生产镜像（不再依赖每日定时）

> tag 必须是 `vX.Y.Z` 格式；本地或远程已存在同名 tag 时脚本会拒绝执行。

### beta 预发布

运行 `.\tag.ps1` 时，脚本会先询问**是否发布正式版**：

- 输入 `y`：打正式版 tag（`vX.Y.Z`），创建正式 Release
- 输入其他任意内容：打 beta 测试版 tag（`vX.Y.Z-beta.N`），同时触发 beta 镜像构建并创建 Prerelease

- beta tag 格式为 `vX.Y.Z-beta.N`，序号 N 自动取本地 + 远程已有序号的最大值 +1（如 v1.4.4-beta.1 → v1.4.4-beta.2）
- 推送后同时触发两个工作流：`build.yml` 按 beta 模式构建镜像（`blazesnow/caddy-beta`，只含 `BETA_PLUGINS`），`version.yml` 创建标为 **Prerelease** 的 Release
- beta tag 可以打在任意分支（dev 或 main）的提交上，tag 名中的 `-beta` 本身决定 beta 模式
- 仍受 manifest 跳过逻辑约束：**非 tag 触发**时插件版本和基础镜像都没变则构建自动跳过；tag 触发（含 beta tag）视为强制构建，**插件和 base 镜像全部重建**

## 本地验证

不依赖 GitHub 就能验证大部分逻辑：

```bash
# bash 语法
bash -n versions.sh set-versions.sh set-base-digests.sh check-base.sh build-caddy.sh write-manifest.sh sync-readme.sh

# JSON 格式化 + 校验
jq . plugins.json

# 模拟 versions.sh（用假的 go list / curl 代替真实查询）
# 注意：脚本在子进程运行，假函数需 export -f 才可见
go() { echo '{"Version":"v1.2.3"}'; }
curl() { cat /tmp/fake_tag.json; }
export -f go curl
export GITHUB_OUTPUT=/tmp/out.txt GITHUB_REF=refs/heads/dev
export BASE_ALPINE=public.ecr.aws/docker/library/alpine:3.24
export BASE_DEBIAN=public.ecr.aws/docker/library/debian:trixie-slim
export BETA_PLUGINS="cloudflare tencentcloud webdav"
bash versions.sh
# 检查 /tmp/out.txt 中的 matrix 是否只包含需要构建的插件
```

## 环境要求

| 工具 | 用途 | 位置 |
| ---- | ---- | ---- |
| jq | 解析/格式化 JSON | 本地 + GitHub runner 均预装 |
| Go | `go list` 版本查询、`xcaddy build` | runner 由 setup-go 提供 |
| Docker | 本地构建/推送镜像 | 本地可选 |
