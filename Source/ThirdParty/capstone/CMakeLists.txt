if(POLICY CMP0042)
  # http://www.cmake.org/cmake/help/v3.0/policy/CMP0042.html
  cmake_policy(SET CMP0042 NEW)
endif(POLICY CMP0042)

if (POLICY CMP0048)
  # use old policy to honor version set using VERSION_* variables to preserve backwards
  # compatibility. change OLD to NEW when minimum cmake version is updated to 3.* and
  # set VERSION using project(capstone VERSION 4.0.0).
  # http://www.cmake.org/cmake/help/v3.0/policy/CMP0048.html
  cmake_policy (SET CMP0048 OLD)
endif()

add_definitions(-DCAPSTONE_USE_SYS_DYN_MEM)

## sources
set(SOURCES_ENGINE
    Source/cs.c
    Source/Mapping.c
    Source/MCInst.c
    Source/MCInstrDesc.c
    Source/MCRegisterInfo.c
    Source/SStream.c
    Source/utils.c
)
set(HEADERS_ENGINE
    Source/cs_simple_types.h
    Source/cs_priv.h
    Source/LEB128.h
    Source/Mapping.h
    Source/MathExtras.h
    Source/MCDisassembler.h
    Source/MCFixedLenDisassembler.h
    Source/MCInst.h
    Source/MCInstrDesc.h
    Source/MCRegisterInfo.h
    Source/SStream.h
    Source/utils.h
)

set(HEADERS_COMMON
    Source/include/capstone/arm64.h
    Source/include/capstone/arm.h
    Source/include/capstone/capstone.h
    Source/include/capstone/evm.h
    Source/include/capstone/wasm.h
    Source/include/capstone/mips.h
    Source/include/capstone/ppc.h
    Source/include/capstone/x86.h
    Source/include/capstone/sparc.h
    Source/include/capstone/systemz.h
    Source/include/capstone/xcore.h
    Source/include/capstone/m68k.h
    Source/include/capstone/tms320c64x.h
    Source/include/capstone/m680x.h
    Source/include/capstone/mos65xx.h
    Source/include/capstone/bpf.h
    Source/include/capstone/riscv.h
    Source/include/capstone/sh.h
    Source/include/capstone/tricore.h
    Source/include/capstone/platform.h

    Source/arch/AArch64/AArch64Module.h
    Source/arch/ARM/ARMModule.h
    Source/arch/EVM/EVMModule.h
    Source/arch/WASM/WASMModule.h
    Source/arch/M680X/M680XModule.h
    Source/arch/M68K/M68KModule.h
    Source/arch/Mips/MipsModule.h
    Source/arch/PowerPC/PPCModule.h
    Source/arch/Sparc/SparcModule.h
    Source/arch/SystemZ/SystemZModule.h
    Source/arch/TMS320C64x/TMS320C64xModule.h
    Source/arch/X86/X86Module.h
    Source/arch/XCore/XCoreModule.h
    Source/arch/RISCV/RISCVModule.h
    Source/arch/MOS65XX/MOS65XXModule.h
    Source/arch/BPF/BPFModule.h
    Source/arch/SH/SHModule.h
    Source/arch/TriCore/TriCoreModule.h
)

## architecture support
if (WTF_CPU_ARM)
    add_definitions(-DCAPSTONE_HAS_ARM)
    set(SOURCES_ARM
        Source/arch/ARM/ARMDisassembler.c
        Source/arch/ARM/ARMInstPrinter.c
        Source/arch/ARM/ARMMapping.c
        Source/arch/ARM/ARMModule.c
    )
    set(HEADERS_ARM
        Source/arch/ARM/ARMAddressingModes.h
        Source/arch/ARM/ARMBaseInfo.h
        Source/arch/ARM/ARMDisassembler.h
        Source/arch/ARM/ARMInstPrinter.h
        Source/arch/ARM/ARMMapping.h
        Source/arch/ARM/ARMGenAsmWriter.inc
        Source/arch/ARM/ARMGenDisassemblerTables.inc
        Source/arch/ARM/ARMGenInstrInfo.inc
        Source/arch/ARM/ARMGenRegisterInfo.inc
        Source/arch/ARM/ARMGenSubtargetInfo.inc
        Source/arch/ARM/ARMMappingInsn.inc
        Source/arch/ARM/ARMMappingInsnOp.inc
        Source/arch/ARM/ARMGenRegisterName.inc
        Source/arch/ARM/ARMGenRegisterName_digit.inc
        Source/arch/ARM/ARMGenSystemRegister.inc
        Source/arch/ARM/ARMMappingInsnName.inc
    )
endif ()

if(WTF_CPU_ARM64)
    add_definitions(-DCAPSTONE_HAS_ARM64)
    set(SOURCES_ARM64
        Source/arch/AArch64/AArch64BaseInfo.c
        Source/arch/AArch64/AArch64Disassembler.c
        Source/arch/AArch64/AArch64InstPrinter.c
        Source/arch/AArch64/AArch64Mapping.c
        Source/arch/AArch64/AArch64Module.c
    )
    set(HEADERS_ARM64
        Source/arch/AArch64/AArch64AddressingModes.h
        Source/arch/AArch64/AArch64BaseInfo.h
        Source/arch/AArch64/AArch64Disassembler.h
        Source/arch/AArch64/AArch64InstPrinter.h
        Source/arch/AArch64/AArch64Mapping.h
        Source/arch/AArch64/AArch64GenAsmWriter.inc
        Source/arch/AArch64/AArch64GenDisassemblerTables.inc
        Source/arch/AArch64/AArch64GenInstrInfo.inc
        Source/arch/AArch64/AArch64GenRegisterInfo.inc
        Source/arch/AArch64/AArch64GenRegisterName.inc
        Source/arch/AArch64/AArch64GenRegisterV.inc
        Source/arch/AArch64/AArch64GenSubtargetInfo.inc
        Source/arch/AArch64/AArch64GenSystemOperands.inc
        Source/arch/AArch64/AArch64GenSystemOperands_enum.inc
        Source/arch/AArch64/AArch64MappingInsn.inc
        Source/arch/AArch64/AArch64MappingInsnName.inc
        Source/arch/AArch64/AArch64MappingInsnOp.inc
    )
endif()

if(WTF_CPU_RISCV)
    add_definitions(-DCAPSTONE_HAS_RISCV)
    set(SOURCES_RISCV
        Source/arch/RISCV/RISCVDisassembler.c
        Source/arch/RISCV/RISCVInstPrinter.c
        Source/arch/RISCV/RISCVMapping.c
        Source/arch/RISCV/RISCVModule.c
    )
    set(HEADERS_RISCV
        Source/arch/RISCV/RISCVBaseInfo.h
        Source/arch/RISCV/RISCVDisassembler.h
        Source/arch/RISCV/RISCVInstPrinter.h
        Source/arch/RISCV/RISCVMapping.h
        Source/arch/RISCV/RISCVModule.h
        Source/arch/RISCV/RISCVGenAsmWriter.inc
        Source/arch/RISCV/RISCVGenDisassemblerTables.inc
        Source/arch/RISCV/RISCVGenInsnNameMaps.inc
        Source/arch/RISCV/RISCVGenInstrInfo.inc
        Source/arch/RISCV/RISCVGenRegisterInfo.inc
        Source/arch/RISCV/RISCVGenSubtargetInfo.inc
        Source/arch/RISCV/RISCVMappingInsn.inc
    )
endif()

set(capstone_SOURCES
    ${SOURCES_ENGINE}
    ${SOURCES_ARM}
    ${SOURCES_ARM64}
    ${SOURCES_RISCV}
    )

set(capstone_HEADERS
    ${HEADERS_COMMON}
    ${HEADERS_ENGINE}
    ${HEADERS_ARM}
    ${HEADERS_ARM64}
    ${HEADERS_RISCV}
    )

set(capstone_INCLUDE_DIRECTORIES "${THIRDPARTY_DIR}/capstone/Source/include")

## targets
add_library(capstone STATIC ${capstone_SOURCES} ${capstone_HEADERS})
set_property(TARGET capstone PROPERTY OUTPUT_NAME capstone)
target_include_directories(capstone PRIVATE ${capstone_INCLUDE_DIRECTORIES})

if (COMPILER_IS_GCC_OR_CLANG)
    WEBKIT_ADD_TARGET_C_FLAGS(capstone
        -Wno-sign-compare
        -Wno-unused-parameter
        -Wno-ignored-qualifiers
        -Wno-implicit-fallthrough
        -Wno-missing-field-initializers
        -Wno-missing-format-attribute
        -Wno-discarded-qualifiers
        -Wno-cast-align
    )
endif ()
