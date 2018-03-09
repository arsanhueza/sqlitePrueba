/// Copyright (c) 2017 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation
import SQLite3
import PlaygroundSupport

destroyPart2Database()
//: # Making it Swift

enum SQLiteError: Error {
  case OpenDatabase(message: String)
  case Prepare(message: String)
  case Step(message: String)
  case Bind(message: String)
}

//: ## The Database Connection

class SQLiteDatabase {
  fileprivate let dbPointer: OpaquePointer?

  fileprivate var errorMessage: String {
    if let errorPointer = sqlite3_errmsg(dbPointer) {
      let errorMessage = String(cString: errorPointer)
      return errorMessage
    } else {
      return "No error message provided from sqlite."
    }
  }

  private init(dbPointer: OpaquePointer?) {
    self.dbPointer = dbPointer
  }

  deinit {
    sqlite3_close(dbPointer)
  }

  static func open(path: String) throws -> SQLiteDatabase {
    var db: OpaquePointer? = nil
    // 1
    if sqlite3_open(path, &db) == SQLITE_OK {
      // 2
      return SQLiteDatabase(dbPointer: db)
    } else {
      // 3
      defer {
        if db != nil {
          sqlite3_close(db)
        }
      }

      if let errorPointer = sqlite3_errmsg(db) {
        let message = String.init(cString: errorPointer)
        throw SQLiteError.OpenDatabase(message: message)
      } else {
        throw SQLiteError.OpenDatabase(message: "No error message provided from sqlite.")
      }
    }
  }
}

let db: SQLiteDatabase
do {
  db = try SQLiteDatabase.open(path: part2DbPath)
  print("Successfully opened connection to database.")
} catch SQLiteError.OpenDatabase(let message) {
  print("Unable to open database. Verify that you created the directory described in the Getting Started section.")
  PlaygroundPage.current.finishExecution()
}

//: ## Preparing Statements

extension SQLiteDatabase {
  func prepareStatement(sql: String) throws -> OpaquePointer? {
    var statement: OpaquePointer? = nil
    guard sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK else {
      throw SQLiteError.Prepare(message: errorMessage)
    }

    return statement
  }
}

//: ## Create Table

struct Contact {
  let id: Int32
  let name: NSString
}

protocol SQLTable {
  static var createStatement: String { get }
}

extension Contact: SQLTable {
  static var createStatement: String {
    return """
    CREATE TABLE Contact(
      Id INT PRIMARY KEY NOT NULL,
      Name CHAR(255)
    );
    """
  }
}

extension SQLiteDatabase {
  func createTable(table: SQLTable.Type) throws {
    // 1
    let createTableStatement = try prepareStatement(sql: table.createStatement)
    // 2
    defer {
      sqlite3_finalize(createTableStatement)
    }
    // 3
    guard sqlite3_step(createTableStatement) == SQLITE_DONE else {
      throw SQLiteError.Step(message: errorMessage)
    }
    print("\(table) table created.")
  }
}

do {
  try db.createTable(table: Contact.self)
} catch {
  print(db.errorMessage)
}

extension SQLiteDatabase {
  func insertContact(contact: Contact) throws {
    let insertSql = "INSERT INTO Contact (Id, Name) VALUES (?, ?);"
    let insertStatement = try prepareStatement(sql: insertSql)
    defer {
      sqlite3_finalize(insertStatement)
    }

    let name: NSString = contact.name
    guard sqlite3_bind_int(insertStatement, 1, contact.id) == SQLITE_OK  &&
      sqlite3_bind_text(insertStatement, 2, name.utf8String, -1, nil) == SQLITE_OK else {
        throw SQLiteError.Bind(message: errorMessage)
    }

    guard sqlite3_step(insertStatement) == SQLITE_DONE else {
      throw SQLiteError.Step(message: errorMessage)
    }

    print("Successfully inserted row.")
  }
}

do {
  try db.insertContact(contact: Contact(id: 1, name: "Ray"))
} catch {
  print(db.errorMessage)
}

//: ## Read

extension SQLiteDatabase {
  func contact(id: Int32) -> Contact? {
    let querySql = "SELECT * FROM Contact WHERE Id = ?;"
    guard let queryStatement = try? prepareStatement(sql: querySql) else {
      return nil
    }

    defer {
      sqlite3_finalize(queryStatement)
    }

    guard sqlite3_bind_int(queryStatement, 1, id) == SQLITE_OK else {
      return nil
    }

    guard sqlite3_step(queryStatement) == SQLITE_ROW else {
      return nil
    }

    let id = sqlite3_column_int(queryStatement, 0)

    let queryResultCol1 = sqlite3_column_text(queryStatement, 1)
    let name = String(cString: queryResultCol1!) as NSString

    return Contact(id: id, name: name)
  }
}

let first = db.contact(id: 1)
print("\(first?.id) \(first?.name)")

