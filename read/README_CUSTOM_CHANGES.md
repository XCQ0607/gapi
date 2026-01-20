原作者仓库：https://github.com/Ellinav/ais2api

# 自定义修改指南：图片支持与 SSE 缓冲

本指南记录了对 `black-browser.js` 的自定义修改。当原作者更新脚本时，您可以参考本指南重新应用您的功能。

## 核心修改：`_processProxyRequest`

主要的修改位于 `ProxySystem` 类的 `_processProxyRequest` 方法中。

**目标**：将默认的响应处理逻辑替换为您支持以下功能的自定义逻辑：

1. **图片响应**：自动将 `image/*` 响应转换为 Base64 并封装在兼容 Google 的 JSON 格式中。
2. **SSE 行缓冲**：确保 `mode === "real"` 流是按行发送（Server-Sent Events 格式），而不是原始数据块。
3. **Imagen 适配器**：在 `fake` 模式下将 Imagen 的 `predictions` 格式转换为 Gemini 的 `candidates` 格式。

### 如何应用

1. 打开新版本的 `black-browser.js`。
2. 在 `ProxySystem` 类中找到 `_processProxyRequest(requestSpec)` 方法。
3. **将整个方法替换**为以下代码：

```javascript
  // [自定义] 处理代理请求，包含图片支持与 SSE 缓冲
  async _processProxyRequest(requestSpec) {
    const operationId = requestSpec.request_id;
    const mode = requestSpec.streaming_mode || "fake";
    Logger.output(`浏览器收到请求`);

    try {
      if (this.requestProcessor.cancelledOperations.has(operationId)) {
        throw new DOMException("The user aborted a request.", "AbortError");
      }
      const { responsePromise } = this.requestProcessor.execute(
        requestSpec,
        operationId
      );
      const response = await responsePromise;
      if (this.requestProcessor.cancelledOperations.has(operationId)) {
        throw new DOMException("The user aborted a request.", "AbortError");
      }

      this._transmitHeaders(response, operationId);

      // --- [自定义功能] 图片支持 ---
      // 检查响应是否为图片，转换为 Base64，并封装为 JSON
      const contentType = response.headers.get("content-type") || "";
      if (contentType.startsWith("image/")) {
        Logger.output(`检测到图片响应 (${contentType})，正在处理二进制数据...`);
        const blob = await response.blob();
        const base64Data = await new Promise((resolve, reject) => {
          const reader = new FileReader();
          reader.onloadend = () => resolve(reader.result.split(",")[1]);
          reader.onerror = reject;
          reader.readAsDataURL(blob);
        });

        // 构造伪造的 Google JSON 响应
        const fakeGoogleResponse = {
          candidates: [
            {
              content: {
                parts: [
                  {
                    inlineData: {
                      mimeType: contentType,
                      data: base64Data,
                    },
                  },
                ],
                role: "model",
              },
              finishReason: "STOP",
              index: 0,
            },
          ],
        };

        const jsonString = JSON.stringify(fakeGoogleResponse);
        this._transmitChunk(`data: ${jsonString}\n\n`, operationId);
        Logger.output("图片数据已封装并发送。");
      } else {
        // --- [自定义功能] 增强的文本/流式处理 ---
        const reader = response.body.getReader();
        const textDecoder = new TextDecoder();
        let fullBody = "";

        let buffer = "";
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          const chunk = textDecoder.decode(value, { stream: true });

          if (mode === "real") {
            // [自定义] SSE 行缓冲
            buffer += chunk;
            let newlineIndex;
            while ((newlineIndex = buffer.indexOf("\n")) !== -1) {
              const line = buffer.substring(0, newlineIndex + 1);
              buffer = buffer.substring(newlineIndex + 1);
              this._transmitChunk(line, operationId);
            }
          } else {
            fullBody += chunk;
          }
        }
        // 在 real 模式下发送剩余的缓冲数据
        if (mode === "real" && buffer.length > 0) {
          this._transmitChunk(buffer, operationId);
        }

        if (mode === "fake") {
          // [自定义] Imagen 转 Gemini 适配器
          try {
            if (fullBody.trim().startsWith("{")) {
              const jsonBody = JSON.parse(fullBody);
              if (jsonBody.predictions && Array.isArray(jsonBody.predictions)) {
                Logger.output(
                  "检测到 Imagen 格式响应，正在转换为 Gemini 格式..."
                );
                const candidates = jsonBody.predictions.map((pred, index) => ({
                  content: {
                    parts: [
                      {
                        inlineData: {
                          mimeType: pred.mimeType || "image/png",
                          data: pred.bytesBase64Encoded,
                        },
                      },
                    ],
                    role: "model",
                  },
                  finishReason: "STOP",
                  index: index,
                }));

                const newBody = { candidates: candidates };
                fullBody = JSON.stringify(newBody);
                Logger.output("转换完成。");
              }
            }
          } catch (e) {
            // 忽略解析错误
          }

          this._transmitChunk(fullBody, operationId);
        }
      }

      Logger.output("数据传输完成。");
      this._transmitStreamEnd(operationId);
    } catch (error) {
      if (error.name === "AbortError") {
        Logger.output(`[诊断] 操作 #${operationId} 已被用户中止。`);
      } else {
        Logger.output(`❌ 请求处理失败: ${error.message}`);
      }
      this._sendErrorResponse(error, operationId);
    } finally {
      this.requestProcessor.activeOperations.delete(operationId);
      this.requestProcessor.cancelledOperations.delete(operationId);
    }
  }
```
