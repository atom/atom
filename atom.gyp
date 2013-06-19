{
  'targets': [
    {
      'target_name': 'Atom',
      'type': 'none',
      'postbuilds': [
        {
          'postbuild_name': 'Create Atom, basically do everything',
          'action': ['script/constructicon/build'],
        },
      ],
    },
  ],
}
