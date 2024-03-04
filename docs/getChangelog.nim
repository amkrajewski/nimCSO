import std/httpclient
import std/json
import std/streams
import std/strutils
import std/times

const 
    changelogType {.strdefine.}: string = "nim"
    user {.strdefine.}: string = "amkrajewski"
    repo {.strdefine.}: string = "nimcso"
    
assert changelogType == "md" or changelogType == "nim", "Invalid changelog type. Only 'md' and 'nim' are supported."

let 
    targetFile = newFileStream("changelog." & changelogType, fmWrite)
    url: string = "https://api.github.com/repos/" & user & "/" & repo & "/releases"
    response = newHttpClient().get(url)
    data = parseJson(response.body)

if changelogType == "md":
    targetFile.writeLine("**Navigation:** [nimCSO](../../nimcso.html) (core) | [Changelog](changelog.html) | [nimcso/bitArrayAutoconfigured](../../nimcso/bitArrayAutoconfigured.html)\n")
elif changelogType == "nim":
    targetFile.writeLine("## **Navigation:** [nimCSO](../../nimcso.html) (core) | [Changelog](changelog.html) | [nimcso/bitArrayAutoconfigured](../../nimcso/bitArrayAutoconfigured.html)\n")

for d in data:
    let 
        tag = d["tag_name"].getStr()
        url = d["html_url"].getStr()
        createdDate = d["created_at"].getStr().parse("yyyy-MM-dd'T'HH:mm:ss'Z'", utc())
        body = d["body"].getStr()

    if changelogType == "md":
        targetFile.writeLine("## " & "[" & tag & "]" & "(" & url & ") (" & createdDate.format("MMM d'st', yyyy") & ")")
        targetFile.writeLine(body)
        targetFile.writeLine("\n")

    if changelogType == "nim":
        targetFile.writeLine("## ## " & tag & " (" & createdDate.format("MMM d'st', yyyy") & ")")
        for line in body.splitLines():
            targetFile.writeLine("## " & line)
        targetFile.writeLine("\n")

targetFile.close()
