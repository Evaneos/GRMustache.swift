//
//  ExpressionInvocation.swift
//  GRMustache
//
//  Created by Gwendal Roué on 26/10/2014.
//  Copyright (c) 2014 Gwendal Roué. All rights reserved.
//

import Foundation

class ExpressionInvocation: ExpressionVisitor {
    let expression: Expression
    var value: MustacheValue
    private var context: Context?
    
    init (expression: Expression) {
        self.value = MustacheValue()
        self.expression = expression
    }
    
    func invokeWithContext(context: Context, error outError: NSErrorPointer) -> Bool {
        self.context = context
        return expression.acceptExpressionVisitor(self, error: outError)
    }
    
    
    // MARK: - ExpressionVisitor
    
    func visit(expression: FilteredExpression, error outError: NSErrorPointer) -> Bool {
        if !expression.filterExpression.acceptExpressionVisitor(self, error: outError) {
            return false
        }
        let filterValue = value
        
        if !expression.argumentExpression.acceptExpressionVisitor(self, error: outError) {
            return false
        }
        let argumentValue = value
        
        switch filterValue.type {
        case .ClusterValue(let cluster):
            if let filter = cluster.mustacheFilter {
                return visit(filter: filter, argumentValue: argumentValue, curried: expression.curried, error: outError)
            } else {
                if outError != nil {
                    outError.memory = NSError(domain: GRMustacheErrorDomain, code: GRMustacheErrorCodeRenderingError, userInfo: [NSLocalizedDescriptionKey: "Not a filter"])
                }
                return false
            }
        case .None:
            if outError != nil {
                outError.memory = NSError(domain: GRMustacheErrorDomain, code: GRMustacheErrorCodeRenderingError, userInfo: [NSLocalizedDescriptionKey: "Missing filter"])
            }
            return false
        default:
            if outError != nil {
                outError.memory = NSError(domain: GRMustacheErrorDomain, code: GRMustacheErrorCodeRenderingError, userInfo: [NSLocalizedDescriptionKey: "Not a filter"])
            }
            return false
        }
    }
    
    func visit(expression: IdentifierExpression, error outError: NSErrorPointer) -> Bool {
        value = context![expression.identifier]
        return true
    }
    
    func visit(expression: ImplicitIteratorExpression, error outError: NSErrorPointer) -> Bool {
        value = context!.topMustacheValue
        return true
    }
    
    func visit(expression: ScopedExpression, error outError: NSErrorPointer) -> Bool {
        if !expression.baseExpression.acceptExpressionVisitor(self, error: outError) {
            return false
        }
        value = value[expression.identifier]
        return true
    }
    
    
    // MARK: - Private
    
    func visit(# filter: MustacheFilter, argumentValue: MustacheValue, curried: Bool, error outError: NSErrorPointer) -> Bool {
        if curried {
            if let curriedFilter = filter.filterByCurryingArgument(argumentValue) {
                value = MustacheValue(curriedFilter)
            } else {
                if outError != nil {
                    outError.memory = NSError(domain: GRMustacheErrorDomain, code: GRMustacheErrorCodeRenderingError, userInfo: [NSLocalizedDescriptionKey: "Too many arguments"])
                }
                return false
            }
        } else {
            var filterError: NSError? = nil
            if let filterResult = filter.transformedValue(argumentValue, error: &filterError) {
                value = filterResult
            } else if let filterError = filterError {
                if outError != nil {
                    outError.memory = filterError
                }
                return false
            } else {
                // Filter result is nil, but filter error is not set.
                // Assume a filter coded by a lazy programmer, whose
                // intention is to return the empty value.
                
                value = MustacheValue()
            }
        }
        return true
    }
    
}