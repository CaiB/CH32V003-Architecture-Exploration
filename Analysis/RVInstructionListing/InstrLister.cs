using System;
using System.Text.RegularExpressions;
using System.Runtime.Intrinsics.X86;

namespace RVInstructionListing;

internal class InstrLister
{
    private static Dictionary<string, string> Instructions = new()
    {
        { "c.mv",       "1000DDDDDSSSSS10" },
        { "c.add",      "1001DDDDDSSSSS10" },
        { "c.and",      "100011DDD11SSS01" },
        { "c.or",       "100011DDD10SSS01" },
        { "c.xor",      "100011DDD01SSS01" },
        { "c.sub",      "100011DDD00SSS01" },
        { "c.li",       "010IDDDDDIIIII01" },
        { "c.lui",      "011IDDDDDIIIII01" },
        { "c.addi",     "000IDDDDDIIIII01" },
        { "c.addi16sp", "011I00010IIIII01" },
        { "c.addi4spn", "000IIIIIIIIDDD00" },
        { "c.andi",     "100I10DDDIIIII01" },
        { "c.slli",     "000IDDDDDIIIII10" },
        { "c.srli",     "100I00DDDIIIII01" },
        { "c.srai",     "100I01DDDIIIII01" },
        { "c.nop",      "000I00000IIIII01" },
        { "c.j",        "101IIIIIIIIIII01" },
        { "c.jal",      "001IIIIIIIIIII01" },
        { "c.jr",       "1000DDDDD0000010" },
        { "c.jalr",     "1001DDDDD0000010" },
        { "c.beqz",     "110IIISSSIIIII01" },
        { "c.bnez",     "111IIISSSIIIII01" },
        { "c.lwsp",     "010IDDDDDIIIII10" },
        { "c.lw",       "010IIISSSIIDDD00" },
        { "c.swsp",     "110IIIIIISSSSS10" },
        { "c.sw",       "110IIIDDDIISSS00" },
        { "xw.c.lbu",   "001IIISSSIIDDD00" },
        { "xw.c.lhu",   "001IIISSSIIDDD10" },
        { "xw.c.sb",    "101IIIDDDIISSS00" },
        { "xw.c.sh",    "101IIIDDDIISSS10" },
        { "xw.c.lbusp", "10000IIII00DDD00" },
        { "xw.c.lhusp", "10000IIII01DDD00" },
        { "xw.c.sbsp",  "10000IIII10SSS00" },
        { "xw.c.shsp",  "10000IIII11SSS00" },
    };

    static int CountSetBits(uint num)
    {
        num = num - ((num >> 1) & 0x55555555);
        num = (num & 0x33333333) + ((num >> 2) & 0x33333333);
        num = (num + (num >> 4)) & 0x0F0F0F0F;
        return (int)((num * 0x01010101u) >> 24);
    }

    static void Main(string[] args)
    {
        string?[] InstructionMap = new string?[65536];

        foreach(KeyValuePair<string, string> Instruction in Instructions)
        {
            uint FixedBits = Convert.ToUInt32(Regex.Replace(Instruction.Value, "[^01]", "0"), 2);
            uint VariableBits = Convert.ToUInt32(Regex.Replace(Regex.Replace(Instruction.Value, "0|1", "0"), "[^0]", "1"), 2);
            int VariableSize = CountSetBits(VariableBits);

            Console.WriteLine("Instruction {0} has pattern {1} and {2} bits of variability.", Instruction.Key, Convert.ToString(VariableBits, 2).PadLeft(16, '0'), VariableSize);

            for (uint i = 0; i < (1 << VariableSize); i++)
            {
                uint VarBitsSet = (uint)Bmi2.X64.ParallelBitDeposit(i, VariableBits);
                ushort ActualInstruction = (ushort)(VarBitsSet | FixedBits);
                InstructionMap[ActualInstruction] = Instruction.Key;
            }
        }

        using (StreamWriter FileWriter = new("rv32c-instructions.txt"))
        {
            for (int i = 0; i < InstructionMap.Length; i++)
            {
                string InstrName;
                if ((i & 0b11) == 0b11) { InstrName = "X"; }
                else { InstrName = InstructionMap[i] ?? "UNK"; }
                FileWriter.Write(InstrName);
                FileWriter.Write(',');
                if (i % 16 == 15) { FileWriter.WriteLine(); }
            }
        }

        using (StreamWriter FileWriter = new("rv32c-instructions.csv"))
        {
            for (int i = 0; i < InstructionMap.Length; i++)
            {
                string InstrName;
                if ((i & 0b11) == 0b11) { InstrName = "X"; }
                else { InstrName = InstructionMap[i] ?? "UNK"; }
                FileWriter.Write(i);
                FileWriter.Write(',');
                FileWriter.WriteLine(InstrName);
            }
        }
    }
}