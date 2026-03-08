import { handle } from '@hono/node-server/vercel'
import app from '../backend/hono'

export const config = {
  runtime: 'nodejs',
}

export default handle(app)