import HTTP
import Vapor
import MySQL
import FluentMySQL
import Fluent

var count = 0
extension Todo {
    func makeJson(with request: Request) throws -> JSON {
        let node = try makeNode()
        return try node.makeJson(with: request)
//        
//        // TODO: Header "Origin"?
//        guard let host = request.headers["Host"]?.finished(with: "/") else { throw Abort.notFound }
//        node["url"] = "\(request.uri.scheme)://\(host)todos/\(id)".makeNode()
//        return try node.converted()
    }
}

extension Node {
    func makeJson(with request: Request) throws -> JSON {
        guard let id = self["id"]?.string else {
            throw Abort.notFound
        }
        guard let host = request.headers["Host"]?.finished(with: "/") else { throw Abort.notFound }
        var node = self
        node["url"] = "\(request.uri.scheme)://\(host)todos/\(id)".makeNode()
        return try node.converted()
    }
}

extension Todo {
    mutating func merge(existing: Todo) {
        id = id ?? existing.id
        // completed is always self
        order = order ?? existing.order
    }
}

final class TodoController: ResourceRepresentable {

    func index(request: Request) throws -> ResponseRepresentable {
        print("\(#function):\n\(request)")
        let json = try Todo.all().map { try $0.makeJson(with: request) }
        return JSON(json)
    }

    func create(request: Request) throws -> ResponseRepresentable {
        print("\(#function):\n\(request)")
        guard
            var todo = try request.json.flatMap({ try Todo(node: $0) })
            else {
                throw Abort.notFound
            }

        try todo.save()
        return try todo.makeJson(with: request)
    }

    func show(request: Request, todo: Todo) throws -> ResponseRepresentable {
        print("\(#function):\n\(request)\n\(todo)")
        return try todo.makeJson(with: request)
    }

    func delete(request: Request, todo: Todo) throws -> ResponseRepresentable {
        print("\(#function):\n\(request)\n\(todo)")
        try todo.delete()
        return JSON([:])
    }

    func clear(request: Request) throws -> ResponseRepresentable {
        print("\(#function):\n\(request)")
        try Todo.query().delete()
        return JSON([])
    }

    func update(request: Request, todo: Todo) throws -> ResponseRepresentable {
        print("\(#function):\n\(request)\n\(todo)")
        guard
            var new = try request.json.flatMap({ try Todo(node: $0) })
            else {
                throw Abort.notFound
            }

        print("orig: \(todo)")
        print("pre : \(new)")
        new.merge(existing: todo)
        print("post: \(new)")
        print("")
        // delete old to workaround save not updating bug
        // try new.save()
        try Todo.query().createOrModify(new.makeNode())
//        guard let db = Todo.database, let msDriver = db.driver as? MySQLDriver else { throw Abort.notFound }
//        msDriver.database.execute("UPDATE \(Todo.entity) SET ", <#T##values: [NodeRepresentable]##[NodeRepresentable]#>, <#T##on: Connection?##Connection?#>)
//        var query = Query<Todo>.init(db)
//        query.action = .modify
//        
//        //let query = try Todo.query()
//        query.sql = .update

        return try new.makeJson(with: request)
    }

    func replace(request: Request, todo: Todo) throws -> ResponseRepresentable {
        print("\(#function):\n\(request)\n\(todo)")
        try todo.delete()
        return try create(request: request)
    }

    lazy var resource: Resource<Todo> = Resource(
        index: self.index,
        store: self.create,
        show: self.show,
        replace: self.replace,
        modify: self.update,
        destroy: self.delete,
        clear: self.clear,
        aboutItem: nil,
        aboutMultiple: nil
    )

    func makeResource() -> Resource<Todo> {
        return Resource(
            index: index,
            store: create,
            show: show,
            replace: replace,
            modify: update,
            destroy: delete,
            clear: clear,
            aboutItem: nil,
            aboutMultiple: nil
        )

        /*
        return Resource(
            index: <#T##Resource.Multiple?##Resource.Multiple?##(Request) throws -> ResponseRepresentable#>,
            store: <#T##Resource.Multiple?##Resource.Multiple?##(Request) throws -> ResponseRepresentable#>,
            show: <#T##(Request, StringInitializable) throws -> ResponseRepresentable?##(Request, StringInitializable) throws -> ResponseRepresentable?##(Request, StringInitializable) throws -> ResponseRepresentable#>,
            replace: <#T##(Request, StringInitializable) throws -> ResponseRepresentable?##(Request, StringInitializable) throws -> ResponseRepresentable?##(Request, StringInitializable) throws -> ResponseRepresentable#>,
            modify: <#T##(Request, StringInitializable) throws -> ResponseRepresentable?##(Request, StringInitializable) throws -> ResponseRepresentable?##(Request, StringInitializable) throws -> ResponseRepresentable#>,
            destroy: <#T##(Request, StringInitializable) throws -> ResponseRepresentable?##(Request, StringInitializable) throws -> ResponseRepresentable?##(Request, StringInitializable) throws -> ResponseRepresentable#>,
            clear: <#T##Resource.Multiple?##Resource.Multiple?##(Request) throws -> ResponseRepresentable#>,
            aboutItem: <#T##(Request, StringInitializable) throws -> ResponseRepresentable?##(Request, StringInitializable) throws -> ResponseRepresentable?##(Request, StringInitializable) throws -> ResponseRepresentable#>,
            aboutMultiple: <#T##Resource.Multiple?##Resource.Multiple?##(Request) throws -> ResponseRepresentable#>
        )
        */
    }
}

/*
class TodoController: Controller {
    typealias Item = Todo
    
    private let todoDao:TodoDao?

    required init(application: Application) {
        do {
            try todoDao = TodoDaoImpl()
        }
        catch {
            Log.error("Could not initialize Todo Dao")
            todoDao = nil
        }
        Log.info("Todo controller created")
    }

    func index(_ request: Request) throws -> ResponseRepresentable {
        if let todoDao = todoDao {
            if let todos = todoDao.findAllTodos() {
                return Json.array(todos.map({ (todo:Todo) -> Json in
                    todo.url = "http://\(request.uri.host!)/todos/\(todo.id!)"
                    return todo.makeJson()
                }))
            } else {
                throw Abort.internalServerError
            }
        } else {
            throw Abort.internalServerError
        }
    }

    func store(_ request: Request) throws -> ResponseRepresentable {
        guard let title = request.data["title"]?.string else {
            throw Abort.badRequest
        }
        if let todoDao = todoDao {
            var completed:Bool
            if request.data["completed"] != nil && request.data["completed"]!.bool != nil {
                completed = request.data["completed"]!.bool!
            } else {
                completed = false
            }
            if let todo = todoDao.createTodo(Todo(id: nil, title: title, completed: completed, order: request.data["order"].int)){
                todo.url = "http://\(request.uri.host!)/todos/\(todo.id!)"
                return todo
            } else {
                throw Abort.internalServerError
            }
        } else {
            throw Abort.internalServerError
        }
    }

    /**
    	Since item is of type Todo,
    	only instances of todo will be received
    */
    func show(_ request: Request, item todo: Todo) throws -> ResponseRepresentable {
        if let todoDao = todoDao {
            if let id = todo.id {
                if let todo = todoDao.getTodoWithId(id) {
                    todo.url = "http://\(request.uri.host!)/todos/\(todo.id!)"
                    return todo
                } else {
                    throw Abort.notFound
                }
            } else {
                throw Abort.badRequest
            }
        } else {
            throw Abort.internalServerError
        }
    }

    func update(_ request: Request, item todo: Todo) throws -> ResponseRepresentable {
        if let todoDao = todoDao {
            if let id = todo.id, let title = request.data["title"]?.string, let completed = request.data["completed"]?.bool, let order = request.data["order"]?.int {
                let todoToUpdate = Todo(id: id, title: title, completed: completed, order: order)
                if let updatedTodo = todoDao.updateTodo(todoToUpdate) {
                    updatedTodo.url = "http://\(request.uri.host!)/todos/\(updatedTodo.id!)"
                    return updatedTodo
                } else {
                    throw Abort.notFound
                }
            } else {
                throw Abort.badRequest
            }
        } else {
            throw Abort.internalServerError
        }
    }
    
    func modify(_ request: Request, item todo: Todo) throws -> ResponseRepresentable {
        if let todoDao = todoDao {
            if let id = todo.id {
                var changes:[String:Any] = [String:Any]()
                if let title = request.data["title"]?.string {
                    changes["title"] = title
                    Log.info("Changing title of todo \(todo.id!) to '\(title)'")
                }
                if let completed = request.data["completed"]?.bool {
                    changes["completed"] = completed
                }
                if let order = request.data["order"]?.int {
                    changes["order"] = order
                }
                if let updatedTodo = todoDao.modifyTodoWithId(id, changes: changes) {
                    updatedTodo.url = "http://\(request.uri.host!)/todos/\(updatedTodo.id!)"
                    return updatedTodo
                } else {
                    throw Abort.notFound
                }
            } else {
                throw Abort.badRequest
            }
        } else {
            throw Abort.internalServerError
        }
    }

    func destroy(_ request: Request, item todo: Todo) throws -> ResponseRepresentable {
        if let todoDao = todoDao {
            if let id = todo.id {
                todoDao.deleteTodoWithId(id)
                return ""
            } else {
                throw Abort.notFound
            }
        } else {
            throw Abort.internalServerError
        }
    }

    func destroyAll(_ request: Request) throws -> ResponseRepresentable {
        if let todoDao = todoDao {
            todoDao.deleteAllTodos()
            return ""
        } else {
            throw Abort.internalServerError
        }
    }
}
*/
