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

package org.eclipse.mita.platform.xdk110.connectivity

import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.TypeGenerator
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import com.google.inject.Inject
import java.nio.ByteBuffer
import java.util.List
import org.yakindu.base.types.inferrer.ITypeSystemInferrer

class BleGenerator extends AbstractSystemResourceGenerator {
	
	@Inject
	protected ITypeSystemInferrer typeInferrer
	
	@Inject
	protected extension GeneratorUtils
	
	@Inject
	protected TypeGenerator typeGenerator
	
	override generateSetup() {
		val baseName = (setup ?: component).baseName;
		
		val deviceName = configuration.getString('deviceName') ?: baseName;
		val serviceUid = configuration.getInteger('serviceUID') ?: baseName.hashCode;
		
		codeFragmentProvider.create('''
		Retcode_T retcode = RETCODE_OK;
		
		retcode = BlePeripheral_Initialize(«baseName»_OnEvent, «baseName»_ServiceRegistry);
		if(retcode != RETCODE_OK)
		{
			return retcode;
		}
		
		retcode = BlePeripheral_SetDeviceName((void *) _BLE_DEVICE_NAME);
		if(retcode != RETCODE_OK)
		{
			return retcode;
		}
		''')
		.addHeader('BCDS_Basics.h', true, IncludePath.VERY_HIGH_PRIORITY)
		.addHeader("BCDS_BlePeripheral.h", true, IncludePath.HIGH_PRIORITY)
		.addHeader("BleTypes.h", true)
		.addHeader("attserver.h", true)
		.setPreamble('''
		#define _BLE_DEVICE_NAME "«deviceName»"
		
		/* «baseName» service */
		static uint8_t «baseName»ServiceUid[ATTPDU_SIZEOF_128_BIT_UUID] = { 0x66, 0x9A, 0x0C, 0x20, 0x00, 0x08, 0xF8, 0x82, 0xE4, 0x11, 0x66, 0x71, «FOR i : ByteBuffer.allocate(4).putInt(serviceUid).array() SEPARATOR ', '»0x«Integer.toHexString(i.bitwiseAnd(0xFF)).toUpperCase»«ENDFOR» };
		static AttServiceAttribute «baseName»Service;
		
		«FOR signalInstance : setup?.signalInstances»
		/* «signalInstance.name» characteristic */
		static Att16BitCharacteristicAttribute «baseName»«signalInstance.name.toFirstUpper»CharacteristicAttribute;
		static uint8_t «baseName»«signalInstance.name.toFirstUpper»UuidValue[ATTPDU_SIZEOF_128_BIT_UUID] = { «signalInstance.characteristicUuid» };
		static AttUuid «baseName»«signalInstance.name.toFirstUpper»Uuid;
		static «typeGenerator.code(ModelUtils.toSpecifier(typeInferrer.infer(signalInstance)?.bindings?.head))» «baseName»«signalInstance.name.toFirstUpper»Value;
		static AttAttribute «baseName»«signalInstance.name.toFirstUpper»Attribute;
		«ENDFOR»
		
		«setup.buildServiceCallback(eventHandler)»
		«setup.buildSetupCharacteristic»
		«setup.buildReadWriteCallback(eventHandler)»
		''')
	}
	
	private static def getCharacteristicUuid(SignalInstance value) {
		val uuidRawValue = StaticValueInferrer.infer(ModelUtils.getArgumentValue(value, 'UUID'), [ ]);
		val uuid = if(uuidRawValue instanceof Integer) {
			uuidRawValue;
		} else {
			value.name.hashCode;
		}
		
		getUuidArrayCode(#[0x66, 0x9A, 0x0C, 0x20, 0x00, 0x08, 0xF8, 0x82, 0xE4, 0x11, 0x66, 0x71], uuid);
	}
	
	private static def getUuidArrayCode(List<Integer> header, Integer tail) {
		val buffer = ByteBuffer.allocate(4);
		buffer.putInt(tail);
		
		'''«FOR i : buffer.array().reverse() SEPARATOR ', '»0x«Integer.toHexString(i.bitwiseAnd(0xFF)).toUpperCase»«ENDFOR», «FOR i : header SEPARATOR ', '»0x«Integer.toHexString(i.bitwiseAnd(0xFF)).toUpperCase»«ENDFOR»'''
	}
	
	private def CodeFragment buildServiceCallback(SystemResourceSetup component, Iterable<EventHandlerDeclaration> declarations) {
		codeFragmentProvider.create('''
		static void «component.baseName»_ServiceCallback(AttServerCallbackParms *serverCallbackParams)
		{
			BCDS_UNUSED(serverCallbackParams);
		}
		
		''')
	}
	
	private def CodeFragment buildReadWriteCallback(SystemResourceSetup component, Iterable<EventHandlerDeclaration> eventHandler) {
		val baseName = component.baseName
		
		codeFragmentProvider.create('''
		static void «baseName»_OnEvent(BlePeripheral_Event_T event, void* data)
		{
		    BCDS_UNUSED(data);
		    Retcode_T retcode = RETCODE_OK;
		
			switch (event)
		    {
		    case BLE_PERIPHERAL_STARTED:
		    	BlePeripheral_Wakeup();
		        break;
		
		    case BLE_PERIPHERAL_CONNECTED:
		        // TODO: add event callback
		        break;
		
		    case BLE_PERIPHERAL_DISCONNECTED:
		        // TODO: add event callback
		        break;
		    case BLE_PERIPHERAL_ERROR:
		        // TODO: add proper error handling
		        break;
		
		    default:
		        /* assertion reason : invalid status of Bluetooth Device */
		        break;
		    }
		    
		    if(retcode != RETCODE_OK)
		    {
		    	Retcode_raiseError(retcode);
			}
		}
		
		''')
		.addHeader('BCDS_Basics.h', true, IncludePath.VERY_HIGH_PRIORITY)
	}
	
	private def CodeFragment buildSetupCharacteristic(SystemResourceSetup component) {
		val baseName = component.baseName
		
		codeFragmentProvider.create('''
		static Retcode_T «baseName»_ServiceRegistry(void)
		{
			Retcode_T retcode = RETCODE_OK;
			
			// register service we'll connect our characteristics to
			ATT_SERVER_SecureDatabaseAccess();
			AttStatus registerStatus = ATT_SERVER_RegisterServiceAttribute(
				ATTPDU_SIZEOF_128_BIT_UUID,
				«baseName»ServiceUid,
				«baseName»_ServiceCallback,
				&«baseName»Service
			);
		    ATT_SERVER_ReleaseDatabaseAccess();
			if(registerStatus != BLESTATUS_SUCCESS)
			{
				return registerStatus;
			}
			
			«FOR signalInstance : setup.signalInstances»
			// setup «signalInstance.name» characteristics
			«baseName»«signalInstance.name.toFirstUpper»Uuid.size = ATT_UUID_SIZE_128;
			«baseName»«signalInstance.name.toFirstUpper»Uuid.value.uuid128 = «baseName»«signalInstance.name.toFirstUpper»UuidValue;
			ATT_SERVER_SecureDatabaseAccess();
			registerStatus = ATT_SERVER_AddCharacteristic(
				ATTPROPERTY_READ | ATTPROPERTY_NOTIFY,
			    &«baseName»«signalInstance.name.toFirstUpper»CharacteristicAttribute,
			    &«baseName»«signalInstance.name.toFirstUpper»Uuid,
			    ATT_PERMISSIONS_ALLACCESS, 
			    «signalInstance.contentLength»,
			    (uint8_t *) &«baseName»«signalInstance.name.toFirstUpper»Value, 
			    FALSE,
			    «signalInstance.contentLength»,
			    &«baseName»Service,
			    &«baseName»«signalInstance.name.toFirstUpper»Attribute
			);
			if(registerStatus != BLESTATUS_SUCCESS)
			{
				return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_FAILURE);
			}
			ATT_SERVER_ReleaseDatabaseAccess();
			
			«ENDFOR»
			
			return retcode;
		}

		''')
	}
	
	private def getContentLength(SignalInstance value) {
		val type = typeInferrer.infer(value)?.bindings?.head?.type;
		return switch(type?.name) {
			case 'bool': 1
			case 'int32': 4
			case 'uint32': 4
			default: null
		}
	}
	
	override generateEnable() {
		codeFragmentProvider.create('''
		Retcode_T retcode = BlePeripheral_Start();
		if(retcode != RETCODE_OK)
		{
			return retcode;
		}
		''')
	}
	
	override generateSignalInstanceSetter(SignalInstance signalInstance, String resultName) {
		val baseName = setup.baseName
		
		codeFragmentProvider.create('''
		if(«resultName» == NULL)
		{
			return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_NULL_POINTER);
		}
		
		// set the new value
		memcpy(&«baseName»«signalInstance.name.toFirstUpper»Value, «resultName», sizeof(«resultName»));
		
		// tell the world via BLE
		Retcode_T retcode = RETCODE_OK;
		ATT_SERVER_SecureDatabaseAccess();
		AttStatus status = ATT_SERVER_WriteAttributeValue(
			&«baseName»«signalInstance.name.toFirstUpper»Attribute,
			(uint8_t*) &«baseName»«signalInstance.name.toFirstUpper»Value,
			«signalInstance.contentLength»
		);
		if (status == BLESTATUS_SUCCESS) /* send notification */
		{
		    status = ATT_SERVER_SendNotification(&«baseName»«signalInstance.name.toFirstUpper»Attribute, 1);
		    /* BLESTATUS_SUCCESS and BLESTATUS_PENDING are fine */
		    if ((status == BLESTATUS_FAILED) || (status == BLESTATUS_INVALID_PARMS))
		    {
		        retcode = RETCODE(RETCODE_SEVERITY_ERROR, (Retcode_T ) RETCODE_SEND_NOTIFICATION_FAILED);
		    }
		}
		else
		{
			if (BLESTATUS_SUCCESS != status)
			{
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, (Retcode_T ) RETCODE_WRITE_ATT_VALUE_FAILED);
			}
		}
		ATT_SERVER_ReleaseDatabaseAccess();
		
		return retcode;
		''')
	}
	
	override generateSignalInstanceGetter(SignalInstance signalInstance, String resultName) {
		val baseName = setup.baseName
		
		codeFragmentProvider.create('''
		if(«resultName» == NULL)
		{
			return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_NULL_POINTER);
		}
		
		memcpy(«resultName», &«baseName»«signalInstance.name.toFirstUpper»Value, sizeof(«resultName»));
		''')
		.addHeader('string.h', true)
	}
	
}