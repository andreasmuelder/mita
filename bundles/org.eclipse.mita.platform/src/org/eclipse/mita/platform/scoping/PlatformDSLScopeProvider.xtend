/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

/*
 * generated by Xtext 2.10.0
 */
package org.eclipse.mita.platform.scoping

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.xtext.scoping.IScope
import org.eclipse.xtext.scoping.Scopes
import org.yakindu.base.expressions.expressions.ElementReferenceExpression
import org.yakindu.base.expressions.expressions.FeatureCall
import org.yakindu.base.types.ComplexType
import org.yakindu.base.types.EnumerationType
import org.yakindu.base.types.inferrer.ITypeSystemInferrer
import org.yakindu.base.expressions.expressions.Expression

/**
 * This class contains custom scoping description.
 * 
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#scoping
 * on how and when to use it.
 */
class PlatformDSLScopeProvider extends AbstractPlatformDSLScopeProvider {

	@Inject
	private ITypeSystemInferrer typeInferrer;

	def IScope scope_FeatureCall_feature(FeatureCall context, EReference reference) {
		val owner = context.owner;
		var EObject element = owner.element;
		
		if (element === null) {
			return getDelegate().getScope(context, reference);
		}

		val scope = IScope.NULLSCOPE;
		val result = typeInferrer.infer(owner);
		val ownerType = result?.type;
		
		return addScopeForType(ownerType, scope);
	}

	def dispatch IScope addScopeForType(EnumerationType type, IScope scope) {
		return Scopes.scopeFor(type.getEnumerator(), scope);
	}

	def dispatch IScope addScopeForType(ComplexType type, IScope scope) {
		return Scopes.scopeFor(type.getAllFeatures(), scope);
	}
	
	def dispatch IScope addScopeForType(Void type, IScope scope) {
		return scope;
	}
	
	def dispatch getElement(Expression it) {
		null
	}
	
	def dispatch getElement(ElementReferenceExpression it) {
		reference
	}
	
	def dispatch getElement(FeatureCall it) {
		feature
	}
}
