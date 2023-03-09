import express from 'express'
import prisma from '../../dbClient.js'
import { handleRejection } from '../../utils.js'
import auth from '../../core/auth.js'
import { UserInContext } from '../../_types'

import { fooBar } from '../../ext-src/apis.js'

const router = express.Router()

router.get('/foo/bar', auth, handleRejection((req: Parameters<typeof fooBar>[0] & UserInContext, res: Parameters<typeof fooBar>[1]) => {
  const context = {
    user: req.user,
    entities: {
    },
  }
  return fooBar(req, res, context)
}))

export default router
