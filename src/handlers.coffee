_ = require 'underscore'

class Response
  constructor: (@body, @statusCode) ->

class InternalError extends Response
  constructor: (@body) ->
    super(@body, 500)

class OkResponse extends Response
  constructor: (@body = {}) ->
    super(@body, 200)

class BadRequest extends Response
  constructor: (@body) ->
    super(@body, 400)

NO_CONTENT = new Response({}, 204)
CREATED = new Response({}, 201)
NOT_FOUND = new Response({}, 404)
  
class Handler
  constructor: (@underlyingHandler) ->
    _.bind(@underlyingHandler, @)
    _.bindAll(@, 'handle', 'getOne', 'filter', 'create')
  handle: (req, res, next) ->
    @underlyingHandler req, (response) ->
      if response
        res.status(response.statusCode)
          .json(response.body)
      else
        next()

  getOne: (req) ->
    detail = req.params.id?
    if !detail
      throw new Error("Trying to getOne not in a detail route")

    req.Model.findById req.param("id")

  filter: (req) ->
    params = _.extend({}, req.body, req.query, req.query.params)
    req.Model.apiQuery(params)

  create: (req) -> 
    new req.Model(req.body)

listHandler = new Handler (req, cb) ->
  @filter(req).exec (err, list) ->
    if err
      cb(new InternalError(err))
    else
      cb(new OkResponse(list))

getHandler = new Handler (req, cb) ->
  @getOne(req).exec (err, obj) ->
    if err
      cb(new InternalError(err))
    else if !obj
      cb(NOT_FOUND)
    else
      cb(new OkResponse(obj))

detailPathHandlerGenerator = (pathName) ->
  detailPathHandler = new Handler (req, cb) ->
    getOne(req).populate(pathName).exec (err, obj) ->
      if err
        cb(new InternalError(err))
      else if !obj
        cb(NOT_FOUND)
      else
        cb(new OkResponse(obj?.get(pathName)))
  detailPathHandler.handle

postHandler = new Handler (req, cb) ->
  @create(req).save (err, obj) ->
    if err
      cb(new BadRequest(err))
    else
      cb(CREATED)

putHandler = new Handler (req, cb) ->
  query = @getOne(req)
  if req.body?._id == req.params.id
    delete req.body._id
  query.findOneAndUpdate {}, req.body, (err, obj) ->
    if err
      cb(new InternalError(err))
    else if !obj
      cb(NOT_FOUND)
    else
      cb(NO_CONTENT)

deleteHandler = new Handler (req, cb) ->
  @getOne(req).findOneAndRemove {}, (err, obj) ->
    if err
      cb(new InternalError(err))
    else if !obj
      cb(NOT_FOUND)
    else
      cb(NO_CONTENT)


module.exports =
  "list": listHandler,
  "detail": getHandler,
  "getDetail": detailPathHandlerGenerator,
  "create": postHandler,
  "update": putHandler,
  "destroy": deleteHandler,
  "preprocess": (Model) ->
    (req, res, next) ->
      req.Model = Model
      next()