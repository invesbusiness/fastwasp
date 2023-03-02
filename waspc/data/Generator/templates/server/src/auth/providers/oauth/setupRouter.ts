import { Router } from "express";
import passport from "passport";

import waspServerConfig from '../../../config.js'
import { sign } from '../../../core/auth.js'
import { authConfig, contextWithUserEntity, findOrCreateUserByExternalAuthAssociation } from "../../utils.js";

import { ProviderConfig, InitData, RequestWithWasp } from "../types.js";

export function setupOAuthRouter(provider: ProviderConfig, initData: InitData) {
    const { passportStrategyName, getUserFieldsFn } = initData;

    const router = Router();

    // Constructs a provider OAuth URL and redirects browser to start sign in flow.
    router.get('/login', passport.authenticate(passportStrategyName, { session: false }));

    // Validates the OAuth code from the frontend, via server-to-server communication
    // with provider. If valid, provides frontend a response containing the JWT.
    // NOTE: `addProviderProfileToRequest` is invoked as part of the `passport.authenticate`
    // call, before the final route handler callback. This is how we gain access to `req.wasp.providerProfile`.
    router.get('/callback',
        passport.authenticate(passportStrategyName, {
            session: false,
            failureRedirect: waspServerConfig.frontendUrl + authConfig.failureRedirectPath
        }),
        async function (req: RequestWithWasp, res) {
            const providerProfile = req?.wasp?.providerProfile;

            if (!providerProfile) {
                throw new Error(`Missing ${provider.name} provider profile on request. This should not happen! Please contact Wasp.`);
            } else if (!providerProfile.id) {
                throw new Error(`${provider.name} provider profile was missing required id property. This should not happen! Please contact Wasp.`);
            }

            // Wrap call to getUserFieldsFn so we can invoke only if needed.
            const getUserFields = () => getUserFieldsFn(contextWithUserEntity, { profile: providerProfile });
            // TODO: In the future we could make this configurable, possibly associating an external account
            // with the currently logged in account, or by some DB lookup.
            const user = await findOrCreateUserByExternalAuthAssociation(provider.slug, providerProfile.id, getUserFields);

            const token = await sign(user.id);
            res.json({ token });
        }
    )

    return router;
}