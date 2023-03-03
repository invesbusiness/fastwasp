import api, { handleApiError } from '../api.js'
import { initSession } from './helpers/user'

export default async function login(username, password) {
  try {
    const args = { username, password }
    const response = await api.post('/auth/local/login', args)

    await initSession(response.data.token)
  } catch (error) {
    handleApiError(error)
  }
}
