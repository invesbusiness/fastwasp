import Auth from './Auth'
import { type CustomizationOptions, State, AdditionalSignupFields } from './types'

export function SignupForm({
  appearance,
  logo,
  socialLayout,
  additionalFields,
}: CustomizationOptions & { additionalFields?: AdditionalSignupFields }) {
  return (
    <Auth
      appearance={appearance}
      logo={logo}
      socialLayout={socialLayout}
      state={State.Signup}
      additionalSignupFields={additionalFields}
    />
  )
}
