import { App } from "wasp-config"

const app = new App('todoApp', {
  title: 'ToDo App',
  wasp: { version: '^0.15.0' },
  // head: []
});

app.webSocket({
  fn: { import: 'webSocketFn', from: '@src/webSocket' },
  // autoConnect: false
});

app.auth({
  userEntity: 'User',
  methods: {
    discord: {
      configFn: { import: 'config', from: '@src/auth/discord' },
      userSignupFields: { import: 'userSignupFields', from: '@src/auth/discord' }
    },
    google: {
      configFn: { import: 'config', from: '@src/auth/google' },
      userSignupFields: { import: 'userSignupFields', from: '@src/auth/google' }
    },
    gitHub: {
      configFn: { import: 'config', from: '@src/auth/github.js' },
      userSignupFields: { import: 'userSignupFields', from: '@src/auth/github.js' }
    },
    // keycloak: {},
    email: {
      userSignupFields: { import: 'userSignupFields', from: '@src/auth/email' },
      fromField: {
        name: "ToDO App",
        email: "mihovil@ilakovac.com"
      },
      emailVerification: {
        getEmailContentFn: { import: 'getVerificationEmailContent', from: '@src/auth/email' },
        clientRoute: 'EmailVerificationRoute',
      },
      passwordReset: {
        getEmailContentFn: { import: 'getPasswordResetEmailContent', from: '@src/auth/email' },
        clientRoute: 'PasswordResetRoute'
      }
    },
  },
  onAuthFailedRedirectTo: '/login',
  onAuthSucceededRedirectTo: '/profile',
  onBeforeSignup: { import: 'onBeforeSignup', from: '@src/auth/hooks.js' },
  onAfterSignup: { import: 'onAfterSignup', from: '@src/auth/hooks.js' },
  onBeforeOAuthRedirect: { import: 'onBeforeOAuthRedirect', from: '@src/auth/hooks.js' },
  onBeforeLogin: { import: 'onBeforeLogin', from: '@src/auth/hooks.js' },
  onAfterLogin: { import: 'onAfterLogin', from: '@src/auth/hooks.js' }
})

app.server({
  setupFn: { importDefault: 'setup', from: '@src/serverSetup' },
  middlewareConfigFn: { import: 'serverMiddlewareFn', from: '@src/serverSetup' },
});

app.client({
  rootComponent: { import: 'App', from: '@src/App' },
  setupFn: { importDefault: 'setup', from: '@src/clientSetup' }
});

app.db({
  seeds: [
    { import: 'devSeedSimple', from: '@src/dbSeeds' },
    { import: 'prodSeed', from: '@src/dbSeeds' }
  ]
});

app.emailSender({
  provider: 'SMTP',
    defaultFrom: {
    email: "mihovil@ilakovac.com"
  }
});

const signupPage = app.page('SignupPage', {
  component: { importDefault: 'Signup', from: '@src/pages/auth/Signup' }
});
app.route('SignupRoute', { path: "/signup", to: signupPage });

const loginPage = app.page('LoginPage', {
  component: { importDefault: 'Login', from: '@src/pages/auth/Login' }
});
app.route('LoginRoute', { path: "/login", to: loginPage });

const passwordResetPage = app.page('PasswordResetPage', {
  component: { import: 'PasswordReset', from: '@src/pages/auth/PasswordReset' }
});
app.route('PasswordResetRoute', { path: "/password-reset", to: passwordResetPage });

const emailVerificationPage = app.page('EmailVerificationPage', {
  component: { import: 'EmailVerification', from: '@src/pages/auth/EmailVerification' }
});
app.route('EmailVerificationRoute', { path: "/email-verification-", to: emailVerificationPage });

const requestPasswordResetPage = app.page('RequestPasswordResetPage', {
  component: { import: 'RequestPasswordReset', from: '@src/pages/auth/RequestPasswordReset' }
});
app.route('RequestPasswordResetRoute', { path: "/request-password-reset", to: requestPasswordResetPage });

const mainPage = app.page('MainPage', {
  authRequired: true,
  component: { importDefault: 'Main', from: '@src/pages/Main' }
});
app.route('HomeRoute', { path: "/", to: mainPage });

const aboutPage = app.page('AboutPage', {
  component: { importDefault: 'About', from: '@src/pages/About' }
});
app.route('AboutRoute', { path: "/about", to: aboutPage });

const profilePage = app.page('ProfilePage', {
  authRequired: true,
  component: { import: 'ProfilePage', from: '@src/pages/ProfilePage' }
});
app.route('ProfileRoute', { path: "/profile", to: profilePage });

const taskPage = app.page('TaskPage', {
  authRequired: true,
  component: { importDefault: 'Task', from: '@src/pages/Task' }
});
app.route('TaskRoute', { path: "/task/:id", to: taskPage });

const catchAllPage = app.page('CatchAllPage', {
  component: { import: 'CatchAllPage', from: '@src/pages/CatchAll' }
});
app.route('CatchAllRoute', { path: "*", to: catchAllPage });

// --------------- Queries ------------- //

app.query('getTasks', {
  fn: { import: 'getTasks', from: '@src/queries' },
  entities: ['Task']
});

app.api('fooBar', {
  fn: { import: 'fooBar', from: '@src/apis' },
  middlewareConfigFn: { import: 'fooBarMiddlewareFn', from: '@src/apis' },
  entities: ['Task'],
  httpRoute: ['ALL', '/foo/bar']
});

app.apiNamespace('bar', {
  middlewareConfigFn: { import: 'barNamespaceMiddlewareFn', from: '@src/apis' },
  path: "/bar"
});

app.api('barBaz', {
  fn: { import: 'barBaz', from: '@src/apis' },
  auth: false,
  entities: ['Task'],
  httpRoute: ['GET', '/bar/baz']
});

app.api('webhookCallback', {
  fn: { import: 'webhookCallback', from: '@src/apis' },
  middlewareConfigFn: { import: 'webhookCallbackMiddlewareFn', from: '@src/apis' },
  httpRoute: ['POST', '/webhook/callback' ],
  auth: false,
});

app.query('getNumTasks', {
  fn: { import: 'getNumTasks', from: '@src/queries' },
  entities: ['Task'],
  auth: false
});

app.query('getTask', {
  fn: { import: 'getTask', from: '@src/queries' },
  entities: ['Task']
});

// --------- Actions --------- //

app.action('createTask', {
  fn: { import: 'createTask', from: '@src/actions' },
  entities: ['Task']
});

app.action('updateTaskIsDone', {
  fn: { import: 'updateTaskIsDone', from: '@src/actions' },
  entities: ['Task']
});

app.action('deleteCompletedTasks', {
  fn: { import: 'deleteCompletedTasks', from: '@src/actions' },
  entities: ['Task']
});

app.action('toggleAllTasks', {
  fn: { import: 'toggleAllTasks', from: '@src/actions' },
  entities: ['Task']
});

// --------- Jobs --------- //

app.job('mySpecialJob', {
  executor: 'PgBoss',
  perform: {
    fn: { import: 'foo', from: '@src/jobs/bar' },
    executorOptions: {
      pgBoss: { retryLimit: 1 }
    }
  },
  entities: ['Task']
});

app.job('mySpecialScheduledJob', {
  executor: 'PgBoss',
  perform: {
    fn: { import: 'foo', from: '@src/jobs/bar' }
  },
  schedule: {
    cron: "0 * * * *",
    args: { foo: "bar" },
    executorOptions: {
      pgBoss: { retryLimit: 2 }
    }
  },
  entities: []
});

// --------- Testing --------- //

app.action('testingAction', {
  fn: { import: 'testingAction', from: '@src/testTypes/operations/server' },
  entities: []
});

app.query('getDate', {
  fn: { import: 'getDate', from: '@src/testTypes/operations/definitions' },
});

app.query('getAnythingNoAuth', {
  fn: { import: 'getAnythingNoAuth', from: '@src/testTypes/operations/definitions' },
  auth: false,
  entities: []
});

app.query('getAnythingAuth', {
  fn: { import: 'getAnythingAuth', from: '@src/testTypes/operations/definitions' },
  auth: true,
  entities: []
});

app.query('getTrueVoid', {
  fn: { import: 'getTrueVoid', from: '@src/testTypes/operations/definitions' },
  entities: []
});

app.query('getAnyNoAuth', {
  fn: { import: 'getAnyNoAuth', from: '@src/testTypes/operations/definitions' },
  auth: false,
  entities: []
});

app.query('getAnyAuth', {
  fn: { import: 'getAnyAuth', from: '@src/testTypes/operations/definitions' },
  auth: true,
  entities: []
});

app.query('getAnyToNumberSpecified', {
  fn: { import: 'getAnyToNumberSpecified', from: '@src/testTypes/operations/definitions' },
  auth: true,
  entities: []
});

app.action('taskToTaskUnspecified', {
  fn: { import: 'taskToTaskUnspecified', from: '@src/testTypes/operations/definitions' },
  entities: ['Task']
});

app.action('taskToTaskSatisfies', {
  fn: { import: 'taskToTaskSatisfies', from: '@src/testTypes/operations/definitions' },
  entities: ['Task']
});

app.action('taskToTaskSpecified', {
  fn: { import: 'taskToTaskSpecified', from: '@src/testTypes/operations/definitions' },
  entities: ['Task']
});

app.action('voidToStringAuth', {
  fn: { import: 'voidToStringAuth', from: '@src/testTypes/operations/definitions' },
  auth: true,
  entities: ['Task']
});

app.action('voidToStringNoAuth', {
  fn: { import: 'voidToStringNoAuth', from: '@src/testTypes/operations/definitions' },
  auth: false,
  entities: ['Task']
});

app.action('unspecifiedToNumber', {
  fn: { import: 'unspecifiedToNumber', from: '@src/testTypes/operations/definitions' },
  entities: ['Task']
});

app.action('boolToStringAuth', {
  fn: { import: 'boolToStringAuth', from: '@src/testTypes/operations/definitions' },
  auth: true,
  entities: ['Task']
});

app.action('boolToStringNoAuth', {
  fn: { import: 'boolToStringNoAuth', from: '@src/testTypes/operations/definitions' },
  auth: false,
  entities: ['Task']
});

app.action('boolToVoidNoAuth', {
  fn: { import: 'boolToVoidNoAuth', from: '@src/testTypes/operations/definitions' },
  auth: false,
  entities: ['Task']
});

app.action('boolToVoidAuth', {
  fn: { import: 'boolToVoidAuth', from: '@src/testTypes/operations/definitions' },
  auth: true,
  entities: ['Task']
});

export default app;
