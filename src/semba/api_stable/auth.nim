import ../protojson

type AuthSignUpResponse* = object
  userId*: ProtoJsonInt64


const fakeUserId* = 696969696969.ProtoJsonInt64

proc auth_SignUp*(): AuthSignUpResponse =
  result.userId = fakeUserId
