{{={= =}=}}
import express from 'express'

{=# isGoogleAuthEnabled =}
import googleAuth from './google/google.js'
{=/ isGoogleAuthEnabled =}

{=# isGithubAuthEnabled =}
import githubAuth from './github/github.js'
{=/ isGithubAuthEnabled =}

const router = express.Router()

{=# isGoogleAuthEnabled =}
router.use('/google', googleAuth)
{=/ isGoogleAuthEnabled =}

{=# isGithubAuthEnabled =}
router.use('/github', githubAuth)
{=/ isGithubAuthEnabled =}

export default router
