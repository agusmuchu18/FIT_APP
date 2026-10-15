/// Existing orientation notes, structured for reuse. Not a reviewed coaching catalogue.
class ExerciseTechnique {
  const ExerciseTechnique(this.summary, this.steps, this.errors, this.tips);
  final String summary;
  final List<String> steps, errors, tips;
}

const exerciseTechniques = {
  'bench_press': ExerciseTechnique(
    'Bajá y empujá la barra de forma controlada.',
    [
      'Acostado en banco, pies apoyados y agarre estable.',
      'Bajá la barra de forma controlada y empujá.',
    ],
    ['Rebotar la barra.'],
    ['Usá soportes y asistencia adecuados.'],
  ),
  'pull_up': ExerciseTechnique(
    'Elevá y descendé el cuerpo con control.',
    [
      'Tomá la barra con agarre prono.',
      'Elevá el cuerpo de forma controlada y descendé sin dejarte caer.',
    ],
    ['Balancearse para completar repeticiones.'],
    ['Conservá un descenso controlado.'],
  ),
  'back_squat': ExerciseTechnique(
    'Flexioná y extendé cadera y rodillas con control.',
    [
      'Apoyá la barra en la parte alta de la espalda, con los pies firmes.',
      'Flexioná cadera y rodillas; volvé a extender.',
    ],
    ['Perder el control de la profundidad.'],
    ['Mantené una profundidad que puedas controlar.'],
  ),
  'deadlift': ExerciseTechnique(
    'Extendé cadera y rodillas con la barra próxima al cuerpo.',
    [
      'Barra cerca de las piernas y agarre firme.',
      'Extendé cadera y rodillas manteniendo la barra próxima al cuerpo.',
    ],
    ['Tirones y movimientos bruscos.'],
    ['Mové la carga con control.'],
  ),
  'military_press': ExerciseTechnique(
    'Empujá la barra por encima de la cabeza y bajá con control.',
    [
      'De pie, colocá la barra delante de los hombros.',
      'Empujá por encima de la cabeza y bajá con control.',
    ],
    ['Compensar con una extensión excesiva del tronco.'],
    ['Mantené el movimiento controlado.'],
  ),
  'plank': ExerciseTechnique(
    'Sostené una posición alineada con respiración regular.',
    [
      'Apoyá antebrazos y puntas de los pies.',
      'Mantené el cuerpo alineado y respiración regular.',
    ],
    ['Continuar cuando ya no podés sostener una posición controlada.'],
    ['Finalizá cuando pierdas el control de la posición.'],
  ),
};
