local API_KEY = ""
local API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" .. API_KEY

local body = textutils.serializeJSON({
    contents = {
        {
            role = "user",
            parts = { { text = "hi" } }
        }
    }
})

local headers = {
    ["Content-Type"] = "application/json"
}

print("Testing Google Gemini API...")
local res, err, errRes = http.post(API_URL, body, headers)

if res then
    print("\n[SUCCESS] Response code: " .. res.getResponseCode())
    print("Response body:")
    print(res.readAll())
    res.close()
elseif errRes then
    print("\n[HTTP ERROR] Code: " .. errRes.getResponseCode())
    print("Error details:")
    print(errRes.readAll())
    errRes.close()
else
    print("\n[CONNECTION FAILED]: " .. tostring(err))
end
