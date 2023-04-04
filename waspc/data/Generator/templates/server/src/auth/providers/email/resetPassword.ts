import { Request, Response } from 'express';
import { handleRejection } from "../../../utils.js";
import { ensureValidTokenAndNewPassword, findUserBy, updateUserPassword, verifyToken } from "../../utils.js";
import { tokenVerificationErrors } from "./types.js";

export const resetPassword = handleRejection(async (
    req: Request<{ token: string; newPassword: string; }>, res: Response,
) => {
    const args = req.body || {};
    ensureValidTokenAndNewPassword(args);
    const { token, newPassword } = args;
    try {
        const { id: userId } = await verifyToken(token);
        const user = await findUserBy<'id'>({ id: userId });
        if (!user) {
            return res.status(400).json({ message: 'Invalid token' });
        }
        await updateUserPassword(userId, newPassword);
    } catch (e) {
        const reason = e.name === tokenVerificationErrors.TokenExpiredError
            ? 'expired'
            : 'invalid';
        return res.status(400).json({ error: `Password reset failed, ${reason} token`});
    }
    res.json({ success: true });
});
