import options
import strutils
import regex
import tables
import sugar

type
  SysInfo = object of RootObj
    id: string
    ver: int

const
  reOsReleaseId = re2 "(?m)^ID=(\"?)(.+)\1"
  reOSReleaseVer = re2 "(?m)^VERSION_ID=(\"?)(.+)\1"

proc read_sysinfo(): Option[SysInfo] =
  var res: SysInfo
  let f = readFile("/etc/os-release")
  var m: RegexMatch2
  if f.find(reOsReleaseId, m):
    res.id = f[m.group(2)]
  else:
    return
  if f.find(reOSReleaseVer, m):
    res.ver = f[m.group(2)].parseInt
  else:
    return
  return some(res)

proc ultramarine_latest(): Option[int] =
  # TODO
  return 39.some


const osTable = {"ultramarine": ultramarine_latest}.toTable

proc determine_update*(): Option[int] =
  let sysinfo = read_sysinfo()
  if sysinfo.is_none(): return
  if sysinfo.get().id notin osTable:
    return some(0)
  result = osTable[sysinfo.get().id]()
  if result == sysinfo.map(x => x.ver):
    return result.map(x => -x)
