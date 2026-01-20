# CFspider 集成说明

## 概述

已成功将 CFspider 代理服务集成到 ais2api 项目中。通过 CFspider，所有对 Google AI API 的请求将通过 Cloudflare Workers 代理转发，从而绕过 IP 地区限制。

## 工作原理

1. **浏览器脚本层拦截**：在 `black-browser.js` 中拦截所有对 `generativelanguage.googleapis.com` 的请求
2. **URL 重写**：将原始 URL 包装为 cfspider 代理请求
3. **Header 转换**：将原始请求头转换为 cfspider 格式（`x-cfspider-header-` 前缀）
4. **认证**：使用 Bearer Token 进行 cfspider 认证

## 环境变量配置

在启动服务器前设置以下环境变量：

### Windows (PowerShell)
```powershell
$env:CFSPIDER_ENDPOINT="https://cfspider.web3.dpdns.org"
$env:CFSPIDER_TOKEN="your-token-here"
```

### Windows (CMD)
```cmd
set CFSPIDER_ENDPOINT=https://cfspider.web3.dpdns.org
set CFSPIDER_TOKEN=your-token-here
```

### Linux/Mac
```bash
export CFSPIDER_ENDPOINT="https://cfspider.web3.dpdns.org"
export CFSPIDER_TOKEN="your-token-here"
```

## 配置选项

| 环境变量 | 说明 | 示例值 |
|---------|------|--------|
| `CFSPIDER_ENDPOINT` | CFspider 服务端点（必需） | `https://cfspider.web3.dpdns.org` |
| `CFSPIDER_TOKEN` | CFspider 认证 token（可选） | `your-secret-token` |

## 快速测试

1. **使用测试脚本**（Windows）:
   ```cmd
   # 编辑 test-cfspider.bat 设置你的 token
   test-cfspider.bat
   ```

2. **手动测试**:
   ```bash
   # 1. 设置环境变量
   export CFSPIDER_ENDPOINT="https://cfspider.web3.dpdns.org"
   export CFSPIDER_TOKEN="your-token"
   
   # 2. 启动服务器
   node unified-server.js
   ```

## 验证

启动服务器后，在日志中查看以下信息：

```
[System] ================ [ 生效配置 ] ================
[System]   ...
[System]   CFspider 代理: ✅ 已启用 (https://cfspider.web3.dpdns.org)
[System] =============================================================
```

当有请求时，浏览器脚本会输出：

```
[ProxyClient] 🌐 CFspider 代理已启用: https://cfspider.web3.dpdns.org
[ProxyClient] 🔀 通过 CFspider 代理: https://cfspider.web3.dpdns.org/proxy?url=...
```

## 禁用 CFspider

如果需要禁用 cfspider 代理，只需不设置 `CFSPIDER_ENDPOINT` 环境变量即可，系统会自动回退到直接请求模式。

## 技术细节

### 修改的文件

1. **black-browser.js**
   - `RequestProcessor` 构造函数：接收 cfspider 配置
   - `_constructUrl()`: URL 重写逻辑
   - `_buildRequestConfig()`: Header 转换和认证
   - `initializeProxySystem()`: 读取全局配置

2. **unified-server.js**
   - `_loadConfiguration()`: 从环境变量读取配置
   - `launchOrSwitchContext()`: 注入配置到浏览器上下文

### 代理流程

```
客户端请求
  ↓
unified-server.js (读取环境变量)
  ↓
注入 window.__CFSPIDER_CONFIG__ 到浏览器
  ↓
black-browser.js (拦截 fetch)
  ↓
Original URL: https://generativelanguage.googleapis.com/...
  ↓
Proxy URL: https://cfspider.web3.dpdns.org/proxy?url=...&method=POST
  ↓
Headers: x-cfspider-header-Content-Type, Authorization: Bearer token
  ↓
CFspider Workers (使用 Cloudflare IP)
  ↓
Google AI API
```

## 故障排查

### 问题：代理未启用
- **检查**：环境变量是否正确设置
- **验证**：查看启动日志中的 "CFspider 代理" 状态

### 问题：401 Unauthorized
- **原因**：Token 无效或未设置
- **解决**：检查 `CFSPIDER_TOKEN` 环境变量

### 问题：请求失败
- **检查**：cfspider 服务是否正常运行
- **验证**：直接访问 `https://cfspider.web3.dpdns.org/debug`

## 注意事项

1. **性能影响**：通过代理会增加 50-200ms 延迟
2. **速率限制**：cfspider 可能有自己的速率限制
3. **Token 安全**：不要在代码中硬编码 token，始终使用环境变量

## 支持

如有问题，请检查：
- CFspider 官方文档：https://github.com/violettoolssite/CFspider
- 项目日志中的详细错误信息
