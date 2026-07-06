import db_connector/db_sqlite

import ../protojson
import ../model_stable/user


type AuthSignUpResponse* = object
  userId*: ProtoJsonInt64

type AuthSignInResponse* = object
  sessionToken*: string
  deviceChanged*: bool
  language*: int


const fakeUserId* = 696969696969.ProtoJsonInt64
const fakeSessionToken* = "69696969-6969-6969-6969-696969696969"


proc auth_SignUp*(): AuthSignUpResponse =
  result.userId = fakeUserId


proc auth_SignIn*(db: DbConn): AuthSignInResponse =
  result.sessionToken = fakeSessionToken
  result.language = getUserLanguage(db)
