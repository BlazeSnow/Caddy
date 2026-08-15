# 开发指南

本文面向本仓库的维护者，说明构建流水线的工作原理、如何添加插件、如何发版，以及本地验证方法。

## 项目结构

```
.
├── .github/workflows/
│   ├── build.yml       # 主构建流水线：查询版本 → 编译 → 推送镜像
│   └── version.yml     # Release 工作流：推送 v* tag 时自动创建 Release
├── plugins.json        # 插件清单（唯一数据源，构建矩阵由此生成）
├── versions.sh         # 版本检查 + 构建矩阵生成（versions job 的逻辑）
├── build-caddy.sh      # xcaddy 编译 amd64/arm64 二进制
├── write-manifest.sh   # 写入构建清单（finalize job）
├── tag.ps1             # 本地打 tag 脚本（推送 tag 触发 Release）
├── Dockerfile          # 运行镜像（Alpine/Debian 双基础镜像），编译产物由 CI 注入
├── Caddyfile           # 默认配置（占位）
├── CHANGELOG.md        # 版本更新日志
└── README.md           # 面向使用者的说明
```

## 构建流水线（build.yml）

每天 UTC 17:00（北京时间凌晨 1:00）自动触发，也可在 GitHub Actions 页面手动触发（`workflow_dispatch`，可选 `force_build=true` 强制忽略版本缓存重建所有镜像）。

### 1. versions job —— 版本检查

- checkout 后读取根目录 `plugins.json`，先做一次合法性校验（必须是非空数组）
- 用 `go list -m ...@latest` 查询 Caddy 和每个插件的最新版本
- 输出两个值：
  - `caddy`：Caddy 版本号
  - `matrix`：JSON 数组，每个元素是 `{name, context, plugin_version}`，作为下游矩阵

插件版本查询全部集中在这里，矩阵 job 不再单独查版本。任一插件查询失败会立刻让整个工作流失败，方便尽早发现问题。

### 2. build job —— 动态矩阵构建

- `matrix.include` 用 `fromJSON(needs.versions.outputs.matrix)` 动态生成，每个插件一个 job
- **跳过判断**：每个 job 先用两个标记文件命中 `actions/cache`（key 分别是 `caddy-<插件>-<Caddy版本>` 和 `caddy-<插件>-plugin-<插件版本>`）。两个缓存都命中且非强制构建时直接跳过，避免版本没变就重复编译
- **编译**：`xcaddy build` 产出 `linux/amd64`、`linux/arm64` 两个二进制（CGO 关闭）
- **推送**：Docker Buildx 多架构构建，推送到 Docker Hub（`blazesnow/caddy`）和 GHCR（`ghcr.io/blazesnow/caddy`），每个插件打 `<插件>-alpine` 和 `<插件>` 两个 tag
- 构建完成后写回标记文件（`echo 版本号 > .build-cache/...`），供下次跳过判断使用

### 3. 注意事项

- 所有 job 串行执行（`max-parallel: 1`），主要顾虑是 Docker Hub 推送速率
- `setup-go` 已关闭内置缓存（`cache: false`），仓库没有 go.mod，内置缓存无法计算 key

### 4. 开发版（beta）镜像

- **在 Actions 页面手动触发工作流并选择 dev 分支**时，镜像推送到 `blazesnow/caddy-beta`（GHCR 为 `ghcr.io/blazesnow/caddy-beta`），tag 结构与生产一致；**其余触发**（定时、main 分支手动）构建生产镜像 `blazesnow/caddy`
- 镜像前缀由 workflow 级 env 的 `IMAGE_PREFIX` / `GHCR_IMAGE_PREFIX` 控制（按 `github.ref` 判断），beta 与生产的 **manifest 缓存相互独立**（`CACHE_NS`），互不影响跳过判断
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

1. 更新 `CHANGELOG.md`，在顶部加当前版本的记录（`## vX.Y.Z` + 日期 + 更新内容）
2. 提交并推送代码
3. 运行发布脚本：

   ```powershell
   .\tag.ps1          # 自动读取 CHANGELOG.md 最新版本
   .\tag.ps1 -Tag v1.5.0   # 或显式指定
   ```

4. 脚本会打印将要执行的操作，输入 `y` 确认后创建并推送 tag（`-NoPush` 只打 tag 不推送）
5. 推送成功后，Actions 的 Version 工作流会自动创建 Release

> tag 必须是 `vX.Y.Z` 格式；本地或远程已存在同名 tag 时脚本会拒绝执行。

## 本地验证

不依赖 GitHub 就能验证大部分逻辑：

```bash
# bash 语法
bash -n versions.sh build-caddy.sh write-manifest.sh

# JSON 格式化 + 校验
jq . plugins.json

# 模拟 versions.sh（用假的 go list / curl 代替真实查询）
go() { echo '{"Version":"v1.2.3"}'; }
curl() { cat /tmp/fake_tag.json; }
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
