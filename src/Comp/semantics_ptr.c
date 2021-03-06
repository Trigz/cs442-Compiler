#include "semantics.h"

struct IdAddr *
doIdAddr(char *name, int SZOff)
{
    struct VarType *vType = doFindVar(name);
    if (!vType)
    {
        WriteIndicator(GetCurrentColumn());
        WriteMessage("Variable Undeclared");
        exit(1);
    }
    struct IdAddr *nAddr = malloc(sizeof(struct IdAddr));
    nAddr->Addr = malloc(sizeof(struct ExprRes));
    nAddr->Addr->Instrs = NULL;
    nAddr->Addr->Reg = AvailTmpReg();
    nAddr->Addr->Type = malloc(sizeof(struct VarType));
    nAddr->Name = name;
    memcpy(nAddr->Addr->Type, vType, sizeof(struct VarType));
    if (vType->Loc == V_GBL)
    {
        nAddr->Addr->Instrs = AppendSeq(nAddr->Addr->Instrs,
            GenInstr(NULL, "la", TmpRegName(nAddr->Addr->Reg), name, NULL));
    }
    else
    {
        nAddr->Addr->Instrs = AppendSeq(nAddr->Addr->Instrs,
            GenInstr(NULL, "addi", TmpRegName(nAddr->Addr->Reg), "$sp",
                                            Imm(vType->SPos)));
        if (SZOff)
        {
            char buf[1024];
            snprintf(buf, 1024, "-%d", SZOff);
            nAddr->Addr->Instrs = AppendSeq(nAddr->Addr->Instrs,
                GenInstr(NULL, "addi", TmpRegName(nAddr->Addr->Reg), TmpRegName(nAddr->Addr->Reg),
                                                buf));
        }
    }
    return nAddr;
}

struct IdAddr *
doDeRef(struct IdAddr *addr, struct ExprRes *offset)
{
    struct ExprRes *addrExpr = addr->Addr;
    if (!addrExpr->Type->isRef)
    {
        typeMismatch();
    }
    AppendSeq(
        addrExpr->Instrs, GenInstr(NULL, "lw", TmpRegName(addrExpr->Reg),
                              RegOff(0, TmpRegName(addrExpr->Reg)), NULL));
    if (offset)
    {
        if (offset->Type->isRef || offset->Type->Type != T_INT)
        {
            typeMismatch();
        }
        addr->Addr->Instrs = AppendSeq(offset->Instrs, addr->Addr->Instrs);
        AppendSeq(
            addr->Addr->Instrs, GenInstr(NULL, "mul", TmpRegName(offset->Reg),
                                    TmpRegName(offset->Reg), "4"));
        AppendSeq(addr->Addr->Instrs,
            GenInstr(NULL, "add", TmpRegName(addr->Addr->Reg),
                      TmpRegName(addr->Addr->Reg), TmpRegName(offset->Reg)));
        ReleaseTmpReg(offset->Reg);
        free(offset->Type);
        free(offset);
    }
    addrExpr->Type->isRef = 0;
    return addr;
}

struct ExprRes *
doAddr(struct IdAddr *addr)
{
    struct ExprRes *addrExpr = addr->Addr;
    if (addrExpr->Type->isRef)
    {
        typeMismatch();
    }
    addrExpr->Type->isRef = 1;
    free(addr->Name);
    free(addr);
    return addrExpr;
}

struct ExprRes *
doSbrk(struct ExprRes *size)
{
    if(size->Type->isRef || size->Type->Type != T_INT)
    {
        typeMismatch();
    }
    AppendSeq(size->Instrs, GenInstr(NULL, "move", "$a0", 
                TmpRegName(size->Reg), NULL));
    AppendSeq(size->Instrs, GenInstr(NULL, "li", "$v0", "9", NULL));
    AppendSeq(size->Instrs, GenInstr(NULL, "syscall", NULL, NULL, NULL));   
    AppendSeq(size->Instrs, GenInstr(NULL, "move", TmpRegName(size->Reg),
                "$v0", NULL));
    size->Type->isRef = 1;
    size->Type->Type = T_VOID;
    return size;
}
