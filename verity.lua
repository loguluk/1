local API_KEY = ""
local API_URL = "https://openrouter.ai/api/v1/chat/completions"

local body = textutils.serializeJSON({
    model = "meta-llama/llama-3.3-70b-instruct:free",
    messages = { { role = "user", content = "hi" } }
})

local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer " .. API_KEY
}

print("Testing OpenRouter API...")
local res, err, errRes = http.post(API_URL, body, headers)

if res then
    print("\n[SUCCESS] Code: " .. res.getResponseCode())
    print("Response:")
    print(res.readAll())
    res.close()
elseif errRes then
    print("\n[HTTP ERROR] Code: " .. errRes.getResponseCode())
    print("Details: " .. errRes.readAll())
    errRes.close()
else
    print("\n[CONNECTION FAILED]: " .. tostring(err))
end
