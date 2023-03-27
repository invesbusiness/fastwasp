import React from 'react'
import { Link } from 'react-router-dom'

import SignupForm from '@wasp/auth/forms/Signup'
import getNumTasks from '@wasp/queries/getNumTasks'
import { useQuery } from '@wasp/queries'
import { getTotalTaskCountMessage } from './helpers'

const Signup = () => {
  const { data: numTasks } = useQuery(getNumTasks)
  return (
    <>
      <SignupForm />
      <br />
      <span>
        I already have an account (<Link to="/login">go to login</Link>).
      </span>
      <br />
      <span>{getTotalTaskCountMessage(numTasks)}</span>
    </>
  )
}

export default Signup
