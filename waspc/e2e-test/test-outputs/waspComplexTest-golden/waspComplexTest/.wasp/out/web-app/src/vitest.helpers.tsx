import React from 'react'
import { rest } from 'msw'
import { setupServer } from 'msw/node'
import { BrowserRouter as Router } from 'react-router-dom'
import { render } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { beforeAll, afterEach, afterAll } from 'vitest'

export function renderWithClient(ui: React.ReactElement): any {
  const client = new QueryClient()
  const { rerender, ...result } = render(
    <QueryClientProvider client={client}><Router>{ui}</Router></QueryClientProvider>
  )
  return {
    ...result,
    rerender: (rerenderUi: React.ReactElement) =>
      rerender(
        <QueryClientProvider client={client}><Router>{rerenderUi}</Router></QueryClientProvider>
      )
  }
}

export const server = setupServer()

export function initCallbacks() {
  beforeAll(() => server.listen())
  afterEach(() => server.resetHandlers())
  afterAll(() => server.close())
}

export function mockQuery(query: any, resJson: any): void {
  const route = query.queryCacheKey[0]
  server.use(
    rest.post(`http://localhost:3001/${route}`, (_req, res, ctx) => {
      return res(ctx.json(resJson))
    })
  )
}