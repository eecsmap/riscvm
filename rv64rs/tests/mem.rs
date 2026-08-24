//! Stage 2 milestone: a program that actually uses the stack region (not
//! just the code region), exercising LUI/ADDI/SW/LW end-to-end through the
//! real Bus + RAM devices set up by Emulator::new -- not just a single
//! execute() call like tests/isa.rs's unit-style ports.

use rv64rs::asm::stack_demo_program;
use rv64rs::emulator::Emulator;

#[test]
fn stack_demo_program_uses_the_stack_correctly() {
    let code = stack_demo_program();
    let mut emu = Emulator::new(&code, 0x1000).unwrap();
    emu.run(); // stops the same way fib.bin does: jalr to ra=0 -> unmapped fetch

    // a0 should hold 43: store 42 to the stack, load it back, increment,
    // store again, load the final value.
    assert_eq!(emu.cpu().regs.read(10), 43);

    // Confirm the intermediate stack writes actually landed in the stack
    // device (not somewhere else): sp was set to 0x3000.
    assert_eq!(emu.bus.read(0x3000, 4).unwrap(), 42);
    assert_eq!(emu.bus.read(0x3004, 4).unwrap(), 43);
}
