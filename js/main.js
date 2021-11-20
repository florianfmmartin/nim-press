const express = require("express")

const app = express()

app.use(express.static("public"))

app.use("/images", express.static(__dirname + "/public/images"))
app.use("/css", express.static(__dirname + "/public/css"))

const port = 3000

const server = app.listen(port, () => {
    console.log(`Listening on port ${port}`)
})
