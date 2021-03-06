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

package org.eclipse.mita.program.validation

import org.eclipse.mita.program.Program
import org.eclipse.mita.program.model.ImportHelper
import org.eclipse.mita.types.PackageAssociation
import org.eclipse.mita.types.TypesPackage
import com.google.inject.Inject
import java.util.Collections
import java.util.HashSet
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.validation.AbstractDeclarativeValidator
import org.eclipse.xtext.validation.Check
import org.eclipse.xtext.validation.CheckType
import org.eclipse.xtext.validation.EValidatorRegistrar
import org.eclipse.mita.library.^extension.LibraryExtensions

class ProgramImportValidator extends AbstractDeclarativeValidator {

	@Inject extension ImportHelper
	
	public static val MISSING_TARGET_PLATFORM_MSG = "Missing target platform import."
	public static val MISSING_TARGET_PLATFORM_CODE = "MissingPlatform"

	@Check(CheckType.NORMAL)
	def checkPackageImportsAreUnique(Program program) {
		val pkgsSeen = new HashSet<String>();
		for (i : program.imports) {
			val pkgName = i.importedNamespace
			if (pkgName !== null && pkgsSeen.contains(pkgName)) {
				error('''Re-importing the "«pkgName»" package.''', i,
					TypesPackage.eINSTANCE.importStatement_ImportedNamespace)
			}
			pkgsSeen.add(pkgName);
		}
	}

	@Check(CheckType.NORMAL)
	def checkPackageImportExists(Program program) {
		val availablePackages = program.eResource.visiblePackages
		program.imports.forEach [
			if (!availablePackages.contains(importedNamespace))
				error('''Package '«importedNamespace»' does not exist.''', it,
					TypesPackage.eINSTANCE.importStatement_ImportedNamespace)
		]
	}

	@Check(CheckType.NORMAL)
	def checkPlatformImportIsPresent(Program program) {
		val availablePackages = LibraryExtensions.availablePlatforms.map[id].toSet
		val importedPlatforms = program.imports.filter[availablePackages.contains(importedNamespace)]
		if (importedPlatforms.nullOrEmpty) {
			error(MISSING_TARGET_PLATFORM_MSG, program, TypesPackage.Literals.PACKAGE_ASSOCIATION__NAME, MISSING_TARGET_PLATFORM_CODE)
		} else if (importedPlatforms.size > 1) {
			error('''Only one target platform must be imported.''', program,
				TypesPackage.Literals.PACKAGE_ASSOCIATION__NAME)
		}
	}

	/**
	 * Users need to import a platform even if they're not using on of its resources,
	 * as the platform provides other basic elements such as exception handling or the event loop.
	 */
	// @Check(CheckType.NORMAL)
	def checkForUnsuedImports(Program program) {
		val imports = program.imports.toSet
		val requiredImports = EcoreUtil.CrossReferencer.find(Collections.singletonList(program)).keySet.map [
			EcoreUtil2.getContainerOfType(it, PackageAssociation)
		].toSet

		val requiredImportNames = requiredImports.map[name].toSet
		imports.forEach [
			if (!requiredImportNames.contains(it.importedNamespace)) {
				warning('''The import «it.importedNamespace»' is never used.''', it,
					TypesPackage.eINSTANCE.importStatement_ImportedNamespace)
			}
		]
	}

	@Inject
	override register(EValidatorRegistrar registrar) {
		// Do not register because this validator is only a composite #398987
	}

}
