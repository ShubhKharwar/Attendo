const express = require('express')
const  studentRouter  = require('./routes/student')
const adminRouter = require('./routes/admin')

const app = express()

app.use('/api/v1/student' , studentRouter)
app.use('/api/v1/admin', adminRouter);

app.listen(3000)