local API_KEY = "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"
local API_URL = "https://openrouter.ai/api/v1/chat/completions"

local body = textutils.serializeJSON({
    model = "meta-llama/llama-3.3-70b-instruct:free",
    messages = { { role = "user", content = "hi" } }
})

local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer " .. API_KEY
}

local res, err, errRes = http.post(API_URL, body, headers)

if res then
    print("SUCCESS Code: " .. res.getResponseCode())
    print(res.readAll())
    res.close()
elseif errRes then
    print("HTTP ERROR Code: " .. errRes.getResponseCode())
    print("Response: " .. errRes.readAll())
    errRes.close()
else
    print("CONNECTION FAILED: " .. tostring(err))
end
